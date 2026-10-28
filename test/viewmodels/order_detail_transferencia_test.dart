import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/domain/bank_details.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/domain/transfer_receipt.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_customer/services/transfer_receipt_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_transfer_receipt_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

class _Picker implements ReceiptPicker {
  _Picker(this.result);

  Object? result;

  @override
  Future<PickedReceipt?> pick(ReceiptSource source) async {
    final r = result;
    if (r is Exception) throw r;
    return r as PickedReceipt?;
  }
}

TransferReceipt receipt(String id,
        {Duration validFor = const Duration(hours: 1)}) =>
    TransferReceipt(
      id: id,
      name: 'foto.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 10,
      uploadedAt: DateTime(2026, 10, 28),
      link: SignedUrl('https://s3/$id', DateTime.now().add(validFor)),
    );

void main() {
  late MockHistoryService history;
  late MockDialogService dialogs;
  late FakeTransferReceiptService transfer;
  final pdf =
      PickedReceipt(Uint8List.fromList([1]), 'a.pdf', 'application/pdf');

  setUpAll(() => initializeDateFormatting('es_AR', null));

  setUp(() {
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    dialogs = locator<DialogService>() as MockDialogService;
    transfer = locator<TransferReceiptService>() as FakeTransferReceiptService;
  });
  tearDown(() => locator.reset());

  Future<OrderDetailViewModel> loaded({
    PaymentMethod method = PaymentMethod.online,
    OrderStatus status = OrderStatus.pending,
    String? paymentStatus = 'pending',
  }) async {
    when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
        order(status: status).copyWith(paymentMethod: method),
        OrderBreakdown(total: 1000, paymentStatus: paymentStatus)));
    final m = OrderDetailViewModel(orderId: 'o1');
    await m.load();
    return m;
  }

  group('visibilidad', () {
    test('transferencia con pago pendiente: datos bancarios y subida',
        () async {
      final m = await loaded();
      expect(m.canPayByTransfer, isTrue);
      expect(m.showTransferCard, isTrue);
      expect(m.hasBankData, isTrue);
      expect(transfer.calls, ['bank:o1', 'receipts:o1']);
    });

    test('con el pago marcado como no recibido también se puede subir',
        () async {
      expect((await loaded(paymentStatus: 'failed')).canPayByTransfer, isTrue);
    });

    for (final c in <(String, PaymentMethod, OrderStatus, String)>[
      ('efectivo', PaymentMethod.cash, OrderStatus.pending, 'pending'),
      (
        'Mercado Pago',
        PaymentMethod.mercadoPago,
        OrderStatus.pending,
        'pending'
      ),
      ('cancelado', PaymentMethod.online, OrderStatus.cancelled, 'pending'),
      ('ya pagado', PaymentMethod.online, OrderStatus.pending, 'paid'),
    ]) {
      test('no se ofrece en un pedido ${c.$1} y no llama al back', () async {
        final m = await loaded(method: c.$2, status: c.$3, paymentStatus: c.$4);
        expect(m.canPayByTransfer, isFalse);
        expect(m.canUploadReceipt, isFalse);
        expect(transfer.calls,
            c.$2 == PaymentMethod.online ? ['receipts:o1'] : isEmpty);
      });
    }

    test('ya pagado con comprobantes subidos: se siguen viendo', () async {
      transfer.list = ApiResult.ok([receipt('a1')]);
      final m = await loaded(paymentStatus: 'paid');
      expect(m.showTransferCard, isTrue);
      expect(m.canUploadReceipt, isFalse);
    });

    test('distribuidora sin datos bancarios: se dice y igual puede subir',
        () async {
      transfer.bank = const ApiResult.ok(BankDetails(holder: 'Distribuidora'));
      final m = await loaded();
      expect(m.bankMissing, isTrue);
      expect(m.canUploadReceipt, isTrue);
    });

    test('si fallan los datos bancarios muestra el error del back', () async {
      transfer.bank = const ApiResult.fail('Sin conexión');
      final m = await loaded();
      expect(m.bankError, 'Sin conexión');
      expect(m.order, isNotNull);
    });

    test('con 5 comprobantes no deja subir otro', () async {
      transfer.list =
          ApiResult.ok([for (var i = 0; i < 5; i++) receipt('a$i')]);
      expect((await loaded()).canUploadReceipt, isFalse);
    });
  });

  group('subir', () {
    test('sube, relee la lista y avisa', () async {
      final m = await loaded();
      m.picker = _Picker(pdf);
      transfer.list = ApiResult.ok([receipt('a1')]);

      await m.uploadReceipt(ReceiptSource.pdf);

      expect(transfer.uploaded.single.filename, 'a.pdf');
      expect(m.receipts.map((r) => r.id), ['a1']);
      expect(m.uploading, isFalse);
      verify(dialogs.showDialog(
        title: 'Comprobante enviado',
        description: anyNamed('description'),
        buttonTitle: 'Aceptar',
      )).called(1);
    });

    test(
        'un rechazo del back se muestra con su mensaje y relee la lista (por si ya estaba)',
        () async {
      final m = await loaded();
      m.picker = _Picker(pdf);
      transfer.uploadResult = const ApiResult.fail(
          'El pedido ya tiene 5 comprobantes',
          status: 409);
      final callsBefore = transfer.calls.length;

      await m.uploadReceipt(ReceiptSource.pdf);

      verify(dialogs.showDialog(
        title: 'No pudimos subir el comprobante',
        description: 'El pedido ya tiene 5 comprobantes',
        buttonTitle: 'Aceptar',
      )).called(1);
      // La subida y la relectura de la lista.
      expect(transfer.calls.length, callsBefore + 2);
      expect(m.uploading, isFalse);
    });

    test('cancelar la selección no sube nada ni molesta', () async {
      final m = await loaded();
      m.picker = _Picker(null);
      await m.uploadReceipt(ReceiptSource.gallery);
      expect(transfer.uploaded, isEmpty);
      verifyNever(dialogs.showDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        buttonTitle: anyNamed('buttonTitle'),
      ));
    });

    test('un archivo muy pesado o ilegible se avisa sin llamar al back',
        () async {
      final m = await loaded();
      m.picker = _Picker(const ReceiptTooLarge());
      await m.uploadReceipt(ReceiptSource.pdf);
      m.picker = _Picker(const PhotoUnreadable());
      await m.uploadReceipt(ReceiptSource.camera);

      expect(transfer.uploaded, isEmpty);
      verify(dialogs.showDialog(
        title: 'No pudimos subir el comprobante',
        description: ReceiptTooLarge.message,
        buttonTitle: 'Aceptar',
      )).called(1);
      verify(dialogs.showDialog(
        title: 'No pudimos subir el comprobante',
        description: PhotoUnreadable.message,
        buttonTitle: 'Aceptar',
      )).called(1);
    });

    test('no se sube en un pedido que no es por transferencia', () async {
      final m = await loaded(method: PaymentMethod.cash);
      m.picker = _Picker(pdf);
      await m.uploadReceipt(ReceiptSource.pdf);
      expect(transfer.uploaded, isEmpty);
    });
  });

  group('copiar y abrir', () {
    test('copiar deja el dato en el portapapeles y lo marca', () async {
      final m = await loaded();
      String? copiedText;
      m.copyToClipboard = (t) async => copiedText = t;
      await m.copy('cbu', '0170099220000067797370');
      expect(copiedText, '0170099220000067797370');
      expect(m.copied, 'cbu');
    });

    test('abre la URL firmada vigente sin volver a pedir la lista', () async {
      transfer.list = ApiResult.ok([receipt('a1')]);
      final m = await loaded();
      Uri? opened;
      m.openUrl = (u) async {
        opened = u;
        return true;
      };
      final before = transfer.calls.length;
      await m.openReceipt(m.receipts.single);
      expect(opened, Uri.parse('https://s3/a1'));
      expect(transfer.calls.length, before);
    });

    test('si la URL venció, pide la lista de nuevo y abre la nueva', () async {
      transfer.list =
          ApiResult.ok([receipt('a1', validFor: -const Duration(minutes: 1))]);
      final m = await loaded();
      transfer.list = ApiResult.ok([
        TransferReceipt(
          id: 'a1',
          name: 'foto.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 10,
          uploadedAt: DateTime(2026, 10, 28),
          link: SignedUrl(
              'https://s3/nueva', DateTime.now().add(const Duration(hours: 1))),
        )
      ]);
      Uri? opened;
      m.openUrl = (u) async {
        opened = u;
        return true;
      };
      await m.openReceipt(m.receipts.single);
      expect(opened, Uri.parse('https://s3/nueva'));
    });

    test('si no se puede abrir avisa', () async {
      transfer.list = ApiResult.ok([receipt('a1')]);
      final m = await loaded();
      m.openUrl = (_) async => false;
      await m.openReceipt(m.receipts.single);
      verify(dialogs.showDialog(
        title: 'No pudimos abrir el comprobante',
        description: anyNamed('description'),
        buttonTitle: 'Aceptar',
      )).called(1);
    });
  });

  group('nombre de la transferencia', () {
    test('en pantalla es Transferencia y al back va transfer', () {
      expect(paymentLabel(PaymentMethod.online), 'Transferencia');
      expect(paymentLabel(PaymentMethod.mercadoPago), 'Mercado Pago');
      expect(OrderApiMapper.serializePaymentMethod(PaymentMethod.online),
          'transfer');
    });

    test('un pedido transfer que viene del back se lee como transferencia', () {
      final o = OrderApiMapper.parseOrder({
        'id': 'o1',
        'paymentMethod': 'transfer',
        'total': 1000,
        'items': [],
      });
      expect(o!.paymentMethod, PaymentMethod.online);
      expect(paymentLabel(o.paymentMethod), 'Transferencia');
    });
  });
}
