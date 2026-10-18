import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/bottom_sheets/receiver/receiver_sheet_model.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockHistoryService history;
  late MockBottomSheetService sheets;
  late MockDialogService dialogs;
  OrderBreakdown? breakdown;

  setUp(() {
    breakdown = const OrderBreakdown(total: 1000);
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    sheets = locator<BottomSheetService>() as MockBottomSheetService;
    dialogs = locator<DialogService>() as MockDialogService;
  });
  tearDown(() => locator.reset());

  Future<OrderDetailViewModel> loaded(OrderStatus status) async {
    when(history.fetchOrderDetail('o1'))
        .thenAnswer((_) async => OrderDetail(order(status: status), breakdown));
    final m = OrderDetailViewModel(orderId: 'o1');
    await m.load();
    return m;
  }

  void chooses(String id, String street) => when(sheets.showCustomSheet(
        variant: anyNamed('variant'),
        title: anyNamed('title'),
        data: anyNamed('data'),
      )).thenAnswer(
          (_) async => SheetResponse(confirmed: true, data: addr(id, street)));

  group('acciones según el estado', () {
    test('pendiente y aceptado: cambiar dirección y quién recibe', () async {
      for (final s in [OrderStatus.pending, OrderStatus.accepted]) {
        final m = await loaded(s);
        expect((m.canChangeAddress, m.canSetReceiver), (true, true),
            reason: '$s');
      }
    });

    test('en camino: ya no cambia la dirección pero sí quién recibe', () async {
      final m = await loaded(OrderStatus.outForDelivery);
      expect((m.canChangeAddress, m.canSetReceiver), (false, true));
    });

    test('entregado o cancelado: ninguna de las dos', () async {
      for (final s in [OrderStatus.delivered, OrderStatus.cancelled]) {
        final m = await loaded(s);
        expect((m.canChangeAddress, m.canSetReceiver), (false, false),
            reason: '$s');
      }
    });

    test('express: no cambia de dirección', () async {
      breakdown =
          const OrderBreakdown(total: 1, deliveryMode: DeliveryMode.express);
      final m = await loaded(OrderStatus.pending);
      expect(m.isExpress, isTrue);
      expect(m.canChangeAddress, isFalse);
    });
  });

  test('sin el desglose no se ofrece cambiar la dirección', () async {
    breakdown = null;
    final m = await loaded(OrderStatus.pending);
    expect(m.canChangeAddress, isFalse);
  });

  test('el texto de la devolución sólo si el pedido se pagó en línea',
      () async {
    breakdown = const OrderBreakdown(total: 1, paymentStatus: 'paid');
    when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
        order().copyWith(paymentMethod: PaymentMethod.mercadoPago), breakdown));
    final online = OrderDetailViewModel(orderId: 'o1');
    await online.load();
    expect(online.paidOnline, isTrue);

    when(history.fetchOrderDetail('o1'))
        .thenAnswer((_) async => OrderDetail(order(), breakdown));
    final cash = OrderDetailViewModel(orderId: 'o1');
    await cash.load();
    expect(cash.paidOnline, isFalse);
  });

  group('cambiar la dirección', () {
    test('el aviso usa lo que devolvió el back aunque falle la relectura',
        () async {
      chooses('a2', 'Belgrano 500');
      final m = await loaded(OrderStatus.pending);
      when(history.changeOrderAddress('o1', 'a2')).thenAnswer((_) async =>
          UpdateOrderResult(
              success: true,
              order: order(address: addr('a2', 'Belgrano 500'), total: 1300)));
      when(history.fetchOrderDetail('o1')).thenThrow(Exception('sin red'));

      await m.changeAddress();

      expect(m.order!.address!.addressId, 'a2');
      final text = verify(dialogs.showDialog(
        title: 'Dirección actualizada',
        description: captureAnyNamed('description'),
        buttonTitle: 'Aceptar',
      )).captured.single as String;
      expect(text, contains('Belgrano 500'));
      expect(text, contains('1.300'));
    });

    test('la elegida va al back, se relee el pedido y se muestra el total',
        () async {
      chooses('a2', 'Belgrano 500');
      final m = await loaded(OrderStatus.pending);
      when(history.changeOrderAddress('o1', 'a2')).thenAnswer((_) async {
        when(history.fetchOrderDetail('o1')).thenAnswer((_) async =>
            OrderDetail(
                order(address: addr('a2', 'Belgrano 500'), total: 1300), null));
        return UpdateOrderResult(success: true, order: order(total: 1300));
      });

      await m.changeAddress();

      expect(m.order!.address!.addressId, 'a2');
      final text = verify(dialogs.showDialog(
        title: 'Dirección actualizada',
        description: captureAnyNamed('description'),
        buttonTitle: 'Aceptar',
      )).captured.single as String;
      expect(text, contains('Belgrano 500'));
      expect(text, contains('1.300'));
      expect(m.saving, isFalse);
    });

    test('elegir la misma dirección no llama al back', () async {
      chooses('a1', 'Mitre 123');
      final m = await loaded(OrderStatus.pending);

      await m.changeAddress();

      verifyNever(
          history.changeOrderAddress(any, any, reason: anyNamed('reason')));
    });

    test('cerrar la hoja sin elegir no llama al back', () async {
      final m = await loaded(OrderStatus.pending);
      when(sheets.showCustomSheet(
        variant: anyNamed('variant'),
        title: anyNamed('title'),
        data: anyNamed('data'),
      )).thenAnswer((_) async => SheetResponse(confirmed: false));

      await m.changeAddress();

      verifyNever(
          history.changeOrderAddress(any, any, reason: anyNamed('reason')));
    });

    test('el 409 del back se muestra tal cual y el pedido se relee', () async {
      chooses('a2', 'Belgrano 500');
      final m = await loaded(OrderStatus.pending);
      const msg =
          'El pedido ya salió o fue entregado: no se puede cambiar la dirección';
      when(history.changeOrderAddress('o1', 'a2')).thenAnswer((_) async =>
          const UpdateOrderResult(
              success: false, message: msg, rejected: true));
      when(history.fetchOrderDetail('o1')).thenAnswer((_) async =>
          OrderDetail(order(status: OrderStatus.outForDelivery), null));

      await m.changeAddress();

      verify(dialogs.showDialog(
        title: 'No pudimos cambiar la dirección',
        description: msg,
        buttonTitle: 'Aceptar',
      )).called(1);
      expect(m.order!.status, OrderStatus.outForDelivery);
      expect(m.canChangeAddress, isFalse);
      expect(m.saving, isFalse);
    });
  });

  group('hoja de quién recibe', () {
    ReceiverSheetModel sheet({String? orderId}) {
      final model = ReceiverSheetModel(orderId: orderId);
      model.nameController.text = 'María Gómez';
      model.documentController.text = '30.123.456';
      model.relationshipController.text = 'vecina';
      return model;
    }

    test('sin pedido sólo valida y devuelve el receptor normalizado', () async {
      final model = sheet();

      expect(await model.submit(), isTrue);

      expect(model.result!.document, '30123456');
      verifyNever(history.setOrderReceiver(any, any));
    });

    test('un dato inválido se explica y no llama al back', () async {
      final model = sheet(orderId: 'o1')..documentController.text = '12';

      expect(await model.submit(), isFalse);

      expect(model.errorMessage, contains('documento'));
      verifyNever(history.setOrderReceiver(any, any));
    });

    test('con pedido lo guarda en el back', () async {
      when(history.setOrderReceiver('o1', any)).thenAnswer(
          (_) async => UpdateOrderResult(success: true, order: order()));
      final model = sheet(orderId: 'o1');

      expect(await model.submit(), isTrue);

      final sent = verify(history.setOrderReceiver('o1', captureAny))
          .captured
          .single as OrderReceiver;
      expect((sent.name, sent.document, sent.relationship),
          ('María Gómez', '30123456', 'vecina'));
    });

    test('si el back rechaza, el error queda en la hoja y no cierra', () async {
      const msg =
          'El pedido ya fue entregado: no se puede indicar quién lo recibe';
      when(history.setOrderReceiver('o1', any)).thenAnswer(
          (_) async => const UpdateOrderResult(success: false, message: msg));
      final model = sheet(orderId: 'o1');

      expect(await model.submit(), isFalse);

      expect(model.errorMessage, msg);
      expect(model.result, isNull);
    });
  });

  test('editar quién recibe abre la hoja con el pedido y relee al guardar',
      () async {
    final m = await loaded(OrderStatus.pending);
    when(sheets.showCustomSheet(
      variant: anyNamed('variant'),
      isScrollControlled: anyNamed('isScrollControlled'),
      enableDrag: anyNamed('enableDrag'),
      data: anyNamed('data'),
    )).thenAnswer((_) async => SheetResponse(confirmed: true));
    when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
        order(),
        const OrderBreakdown(
            total: 1000,
            receiver: OrderReceiver(
                name: 'Ana', document: '30123456', relationship: 'hermana'))));

    await m.editReceiver();

    final data = verify(sheets.showCustomSheet(
      variant: anyNamed('variant'),
      isScrollControlled: anyNamed('isScrollControlled'),
      enableDrag: anyNamed('enableDrag'),
      data: captureAnyNamed('data'),
    )).captured.single as Map;
    expect(data['orderId'], 'o1');
    expect(m.receiver!.name, 'Ana');
  });

  test('al cerrar la hoja de quién recibe sin guardar, igual relee el pedido',
      () async {
    final m = await loaded(OrderStatus.pending);
    when(sheets.showCustomSheet(
      variant: anyNamed('variant'),
      isScrollControlled: anyNamed('isScrollControlled'),
      enableDrag: anyNamed('enableDrag'),
      data: anyNamed('data'),
    )).thenAnswer((_) async => SheetResponse(confirmed: false));
    when(history.fetchOrderDetail('o1')).thenAnswer((_) async =>
        OrderDetail(order(status: OrderStatus.delivered), breakdown));

    await m.editReceiver();

    expect(m.order!.status, OrderStatus.delivered);
    expect(m.canSetReceiver, isFalse);
  });
}
