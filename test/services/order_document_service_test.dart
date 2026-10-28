import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/services/order_document_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

import '../helpers/fake_http.dart';
import '../helpers/test_helpers.dart';

void main() {
  final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]); // %PDF-
  late List<(Uint8List, String)> shared;
  late OrderDocumentService service;

  setUp(() {
    registerServices();
    shared = [];
    service = OrderDocumentService(
      tokenReader: () async => 'tok',
      share: (bytes, name) async {
        shared.add((bytes, name));
        return true;
      },
    );
  });
  tearDown(() => locator.reset());

  group('OrderDocumentService -', () {
    test('baja el remito de la v2 con la sesión y las cabeceras de la app',
        () async {
      final log = fakeHttp((_) => FakeReply(200, pdf));
      final r = await service.download('o1', OrderDocument.remito);

      expect(r.ok, isTrue);
      expect(r.data, pdf);
      expect(log.single.method, 'GET');
      expect(log.single.path,
          '${AppConfig.apiBaseUrl}/api/v2/orders/o1/remito.pdf');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      expect(log.single.headers['X-Client-Source'], 'customer-app');
      expect(log.single.headers['X-Distributor'], AppConfig.distributorSlug);
    });

    test('el recibo pega a recibo.pdf', () async {
      final log = fakeHttp((_) => FakeReply(200, pdf));
      await service.download('o1', OrderDocument.recibo);
      expect(log.single.path, endsWith('/api/v2/orders/o1/recibo.pdf'));
    });

    test('open entrega los bytes a la hoja nativa con el nombre del archivo',
        () async {
      fakeHttp((_) => FakeReply(200, pdf));
      final r = await service.open('o1', OrderDocument.recibo);

      expect(r.ok, isTrue);
      expect(shared.single.$1, pdf);
      expect(shared.single.$2, 'recibo-O1.pdf');
      expect(
        OrderDocumentService.filename(
            '0314ed62-e97d-42f7-8fae-93fc78ae4aba', OrderDocument.remito),
        'remito-0314ED62.pdf',
      );
    });

    test('un 409 del back llega con su mensaje y no se comparte nada',
        () async {
      fakeHttp((_) => const FakeReply(409, {
            'message': 'El pedido está cancelado: no tiene recibo.',
          }));
      final r = await service.open('o1', OrderDocument.recibo);

      expect(r.ok, isFalse);
      expect(r.status, 409);
      expect(r.message, 'El pedido está cancelado: no tiene recibo.');
      expect(shared, isEmpty);
    });

    test('un 404 usa el texto propio y sin red avisa que no hay conexión',
        () async {
      fakeHttp((_) => const FakeReply(404, {'message': 'Not Found'}));
      expect((await service.open('o1', OrderDocument.remito)).message,
          ApiErrorText.notFound);

      fakeHttp((_) => const FakeReply.networkError());
      expect((await service.open('o1', OrderDocument.remito)).message,
          ApiErrorText.offline);
      expect(shared, isEmpty);
    });

    test('sin sesión no llama al back', () async {
      final log = fakeHttp((_) => FakeReply(200, pdf));
      final noSession = OrderDocumentService(tokenReader: () async => null);
      final r = await noSession.open('o1', OrderDocument.remito);

      expect(r.message, ApiErrorText.sessionExpired);
      expect(log, isEmpty);
    });

    test('si falla la hoja nativa devuelve error en vez de éxito', () async {
      fakeHttp((_) => FakeReply(200, pdf));
      final broken = OrderDocumentService(
        tokenReader: () async => 'tok',
        share: (_, __) async => throw Exception('sin hoja'),
      );
      final r = await broken.open('o1', OrderDocument.remito);
      expect(r.ok, isFalse);
    });
  });
}
