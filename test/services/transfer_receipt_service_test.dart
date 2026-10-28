import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_customer/services/transfer_receipt_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

import '../helpers/fake_http.dart';
import '../helpers/test_helpers.dart';

void main() {
  late TransferReceiptService service;
  final file = PickedReceipt(
      Uint8List.fromList([1, 2, 3]), 'comprobante.jpg', 'image/jpeg');

  setUp(() {
    registerServices();
    service = TransferReceiptService(tokenReader: () async => 'tok');
  });
  tearDown(() => locator.reset());

  group('datos bancarios', () {
    test('pide la v2 con la sesión y arma el modelo', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            'cbu': '0170099220000067797370',
            'alias': 'garrafas.splg',
            'holder': null,
          }));
      final r = await service.bankDetails('o1');

      expect(r.ok, isTrue);
      expect(r.data!.cbu, '0170099220000067797370');
      expect(r.data!.alias, 'garrafas.splg');
      expect(r.data!.holder, isNull);
      expect(r.data!.canTransfer, isTrue);
      expect(log.single.method, 'GET');
      expect(log.single.path,
          '${AppConfig.apiBaseUrl}/api/v2/orders/o1/bank-details');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      expect(log.single.headers['X-Distributor'], AppConfig.distributorSlug);
    });

    test('sin CBU ni alias no hay con qué transferir', () async {
      fakeHttp((_) => const FakeReply(
          200, {'cbu': null, 'alias': '  ', 'holder': 'Distribuidora'}));
      final r = await service.bankDetails('o1');
      expect(r.data!.canTransfer, isFalse);
    });

    test('el 400 del back llega con su mensaje', () async {
      fakeHttp((_) => const FakeReply(
          400, {'message': 'El pedido no se paga por transferencia'}));
      final r = await service.bankDetails('o1');
      expect(r.ok, isFalse);
      expect(r.message, 'El pedido no se paga por transferencia');
    });
  });

  group('comprobantes', () {
    test('lista los de la v2 y descarta los que vienen sin URL', () async {
      final log = fakeHttp((_) => FakeReply(200, [
            {
              'attachmentId': 'a1',
              'originalName': 'foto.jpg',
              'mimeType': 'image/jpeg',
              'sizeBytes': 2048,
              'uploadedAt': '2026-10-28T12:00:00.000Z',
              'url': 'https://s3/x?firma=1',
              'expiresAt': '2099-01-01T00:00:00.000Z',
            },
            {'attachmentId': 'a2', 'originalName': 'roto.pdf'},
          ]));
      final r = await service.receipts('o1');

      expect(log.single.path,
          '${AppConfig.apiBaseUrl}/api/v2/orders/o1/transfer-receipt');
      expect(r.data!.map((e) => e.id), ['a1']);
      expect(r.data!.single.isPdf, isFalse);
      expect(r.data!.single.link.isValid, isTrue);
    });

    test('sin red avisa que no hay conexión', () async {
      fakeHttp((_) => const FakeReply.networkError());
      expect((await service.receipts('o1')).message, ApiErrorText.offline);
    });
  });

  group('subir', () {
    test('multipart al endpoint v2 con sesión e Idempotency-Key', () async {
      final log = fakeHttp((_) => const FakeReply(201, {'id': 'a1'}));
      final r = await service.upload('o1', file);

      expect(r.ok, isTrue);
      expect(log.single.method, 'POST');
      expect(log.single.path,
          '${AppConfig.apiBaseUrl}/api/v2/orders/o1/transfer-receipt');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      expect(log.single.headers['X-Client-Source'], 'customer-app');
      expect(log.single.headers['Idempotency-Key'], isNotEmpty);
      final form = log.single.options.data as dynamic;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'comprobante.jpg');
    });

    test('tras una falla de red el reintento lleva la misma clave', () async {
      var n = 0;
      final log = fakeHttp((_) =>
          n++ == 0 ? const FakeReply.networkError() : const FakeReply(201, {}));
      await service.upload('o1', file);
      await service.upload('o1', file);
      expect(
          log[1].headers['Idempotency-Key'], log[0].headers['Idempotency-Key']);
    });

    test('tras un rechazo del back la clave se descarta', () async {
      var n = 0;
      final log = fakeHttp((_) => n++ == 0
          ? const FakeReply(409, {'message': 'El pago ya se resolvió'})
          : const FakeReply(201, {}));
      final first = await service.upload('o1', file);
      await service.upload('o1', file);
      expect(first.message, 'El pago ya se resolvió');
      expect(first.status, 409);
      expect(log[1].headers['Idempotency-Key'],
          isNot(log[0].headers['Idempotency-Key']));
    });

    test('413 y 415 explican qué pasó', () async {
      fakeHttp((_) => const FakeReply(415, {'message': 'Unsupported'}));
      expect((await service.upload('o1', file)).message,
          'Subí una foto (JPG, PNG o WEBP) o un PDF.');
      fakeHttp((_) => const FakeReply(413, {'message': 'Too large'}));
      final r = await service.upload('o1', file);
      expect(r.status, 413);
      expect(r.message, contains('10 MB'));
    });

    test('sin sesión no llama al back', () async {
      final log = fakeHttp((_) => const FakeReply(201, {}));
      final noSession = TransferReceiptService(tokenReader: () async => null);
      final r = await noSession.upload('o1', file);
      expect(r.message, ApiErrorText.sessionExpired);
      expect(log, isEmpty);
    });
  });

  group('PDF elegido', () {
    test('uno válido entra con su nombre y tipo', () {
      final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 1]);
      final r = ReceiptPicker.fromPdfBytes('mi.pdf', pdf);
      expect(r.contentType, 'application/pdf');
      expect(r.filename, 'mi.pdf');
    });

    test('algo que no es un PDF o que pesa de más se rechaza', () {
      expect(() => ReceiptPicker.fromPdfBytes('x.pdf', Uint8List(10)),
          throwsA(isA<ReceiptUnreadable>()));
      final big = Uint8List(ReceiptPicker.maxBytes + 1);
      expect(() => ReceiptPicker.fromPdfBytes('x.pdf', big),
          throwsA(isA<ReceiptTooLarge>()));
    });
  });
}
