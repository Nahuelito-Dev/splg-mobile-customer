import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/services/order_tracking_service.dart';

import '../helpers/fake_http.dart';

void main() {
  late OrderTrackingService service;

  setUp(() => service = OrderTrackingService());

  group('confirmDelivery', () {
    test('el 201 con el que responde el back es éxito', () async {
      final log = fakeHttp((_) => const FakeReply(201, {'id': 'o1'}));

      final outcome = await service.confirmDelivery('o1', 'ABC123', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.success);
      expect(log.single.method, 'POST');
      expect(log.single.path, 'orders/o1/confirm-delivery');
      expect(log.single.body, {'code': 'ABC123'});
      expect(log.single.headers['Idempotency-Key'], isNotEmpty);
    });

    test('un 200 también es éxito', () async {
      fakeHttp((_) => const FakeReply(200, {'id': 'o1'}));
      final outcome = await service.confirmDelivery('o1', 'ABC123', 'tok');
      expect(outcome.result, ConfirmDeliveryResult.success);
    });

    test('un 400 de negocio es código inválido y trae el mensaje del back',
        () async {
      fakeHttp((_) => const FakeReply(400, {
            'statusCode': 400,
            'message': 'Código de entrega inválido',
          }));

      final outcome = await service.confirmDelivery('o1', 'MAL', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.invalidCode);
      expect(outcome.message, 'Código de entrega inválido');
    });

    test('un 400 con code de otro pedido es otherOrder', () async {
      fakeHttp((_) => const FakeReply(400, {
            'statusCode': 400,
            'message': 'Ese código es de otro de tus pedidos en camino',
            'code': 'DELIVERY_CODE_OTRO_PEDIDO',
          }));

      final outcome = await service.confirmDelivery('o1', '0123456789', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.otherOrder);
      expect(outcome.message, OrderTrackingService.otherOrderText);
    });

    test('un 409 con DELIVERY_CODE_BLOQUEADO es blocked, no un error genérico',
        () async {
      fakeHttp((_) => const FakeReply(409, {
            'statusCode': 409,
            'message': 'Demasiados intentos: pedile al chofer un código nuevo',
            'code': 'DELIVERY_CODE_BLOQUEADO',
          }));

      final outcome = await service.confirmDelivery('o1', '482913', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.blocked);
      expect(outcome.message, OrderTrackingService.blockedText);
    });

    test('un 400 con code de formato es malformedCode', () async {
      fakeHttp((_) => const FakeReply(400, {
            'statusCode': 400,
            'message': 'x',
            'code': 'DELIVERY_CODE_FORMATO',
          }));

      final outcome = await service.confirmDelivery('o1', 'MAL', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.malformedCode);
      expect(outcome.message, OrderTrackingService.malformedCodeText);
    });

    test('un 400 con code incorrecto sigue siendo invalidCode', () async {
      fakeHttp((_) => const FakeReply(400, {
            'statusCode': 400,
            'message': 'Código de entrega inválido',
            'code': 'DELIVERY_CODE_INCORRECTO',
          }));

      final outcome = await service.confirmDelivery('o1', 'FFFFFFFFFF', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.invalidCode);
      expect(outcome.message, 'Código de entrega inválido');
    });

    test('un 400 con mensaje técnico usa el texto propio', () async {
      fakeHttp((_) => const FakeReply(400, {'message': 'Bad Request'}));

      final outcome = await service.confirmDelivery('o1', 'MAL', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.invalidCode);
      expect(outcome.message, contains('código'));
    });

    test('sin respuesta es error de red, no código inválido', () async {
      fakeHttp((_) => const FakeReply.networkError());

      final outcome = await service.confirmDelivery('o1', 'ABC123', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.networkError);
      expect(outcome.message, contains('conexión'));
    });

    test('un 401 es sesión vencida', () async {
      fakeHttp((_) => const FakeReply(401, {'message': 'Unauthorized'}));

      final outcome = await service.confirmDelivery('o1', 'ABC123', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.sessionExpired);
    });

    test('un 500 es una falla, no código inválido', () async {
      fakeHttp((_) => const FakeReply(500, {'message': 'Internal'}));

      final outcome = await service.confirmDelivery('o1', 'ABC123', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.failed);
    });
  });

  group('confirmDelivery - Idempotency-Key', () {
    Future<List<Object?>> intentos(
        List<FakeReply> respuestas, List<String> codigos) async {
      var i = 0;
      final log = fakeHttp((_) => respuestas[i++]);
      for (final code in codigos) {
        await service.confirmDelivery('o1', code, 'tok');
      }
      return log.map((r) => r.headers['Idempotency-Key']).toList();
    }

    test('sin respuesta, 5xx, 429, 409 en curso y 422 reusan la clave',
        () async {
      final claves = await intentos([
        const FakeReply.networkError(),
        const FakeReply(500, {'message': 'x'}),
        const FakeReply(429, {'message': 'x'}),
        const FakeReply(
            409, {'message': 'Request en curso con la misma Idempotency-Key'}),
        const FakeReply(422, {
          'message': 'Esa clave de idempotencia ya se usó con otros datos.'
        }),
        const FakeReply(201, {'id': 'o1'}),
      ], List.filled(6, 'ABC123'));

      expect(claves.toSet(), hasLength(1));
    });

    test('tras el éxito o un 400 de negocio, el próximo intento usa otra',
        () async {
      final claves = await intentos([
        const FakeReply(400, {'message': 'Código de entrega inválido'}),
        const FakeReply(201, {'id': 'o1'}),
        const FakeReply(201, {'id': 'o1'}),
      ], List.filled(3, 'ABC123'));

      expect(claves.toSet(), hasLength(3));
    });

    test('otro código es otra intención', () async {
      final claves = await intentos([
        const FakeReply.networkError(),
        const FakeReply.networkError(),
      ], [
        'AAA111',
        'BBB222'
      ]);

      expect(claves.toSet(), hasLength(2));
    });

    test('el 422 de clave ya usada se explica sin culpar al código', () async {
      fakeHttp((_) => const FakeReply(422,
          {'message': 'Esa clave de idempotencia ya se usó con otros datos.'}));

      final outcome = await service.confirmDelivery('o1', 'ABC123', 'tok');

      expect(outcome.result, ConfirmDeliveryResult.failed);
      expect(outcome.message, contains('Ya recibimos'));
    });
  });

  group('fetchOrderById', () {
    test('404 y 410 no se reintentan: el pedido ya no está', () async {
      for (final status in [404, 410]) {
        fakeHttp((_) => FakeReply(status, {'message': 'x'}));
        await expectLater(
            service.fetchOrderById('o1', 'tok'),
            throwsA(isA<LoadFailure>()
                .having((f) => f.retryable, 'retryable', false)));
      }
    });

    test('red y 5xx dan null (se puede reintentar)', () async {
      fakeHttp((_) => const FakeReply.networkError());
      expect(await service.fetchOrderById('o1', 'tok'), isNull);
      fakeHttp((_) => const FakeReply(503, {'message': 'x'}));
      expect(await service.fetchOrderById('o1', 'tok'), isNull);
    });
  });

  group('auth del socket', () {
    Future<Map<String, dynamic>> handshake(
        void Function(void Function(Map<String, dynamic>)) auth) {
      final out = Completer<Map<String, dynamic>>();
      auth(out.complete);
      return out.future;
    }

    test('pide el token en cada conexión, no uno solo al abrir', () async {
      var n = 0;
      final auth = OrderTrackingService.authFor(() async => 'tok-${++n}');

      expect(await handshake(auth), {'token': 'tok-1'});
      expect(await handshake(auth), {'token': 'tok-2'});
    });

    test('sin token manda el handshake vacío en vez de romper', () async {
      final auth = OrderTrackingService.authFor(() async => null);
      expect(await handshake(auth), isEmpty);

      final failing = OrderTrackingService.authFor(() async => throw 'boom');
      expect(await handshake(failing), isEmpty);
    });
  });

  group('eventos del socket', () {
    test('order:cancelled: el motivo (reason) sale antes que el estado',
        () async {
      final out = <String>[];
      service.cancellationReasons.listen((r) => out.add('reason:$r'));
      service.orderStatusUpdates.listen((s) => out.add('status:$s'));

      service.onOrderStatusUpdate({
        'orderId': 'o1',
        'status': 'cancelled',
        'reason': 'Cancelado por customer',
      });
      await Future<void>.delayed(Duration.zero);

      expect(out, ['reason:Cancelado por customer', 'status:cancelled']);
    });

    test('order:searching-driver llega como estado pendiente', () async {
      final out = <String>[];
      service.orderStatusUpdates.listen(out.add);

      service.onOrderStatusUpdate({'orderId': 'o1', 'status': 'pending'});
      await Future<void>.delayed(Duration.zero);

      expect(out, ['pending']);
    });

    test('order:arrived avisa que el repartidor llegó', () async {
      var llegadas = 0;
      service.arrivedUpdates.listen((_) => llegadas++);

      service.onArrived({'orderId': 'o1', 'driverName': 'Juan'});
      await Future<void>.delayed(Duration.zero);

      expect(llegadas, 1);
    });

    test('order:express-degraded avisa que pasó al reparto común', () async {
      var avisos = 0;
      service.expressDegradedUpdates.listen((_) => avisos++);

      service.onExpressDegraded({'orderId': 'o1', 'surchargeRemoved': true});
      await Future<void>.delayed(Duration.zero);

      expect(avisos, 1);
    });

    test(
        'order:updated, payment-approved y payment-refunded piden releer el pedido',
        () async {
      var avisos = 0;
      service.orderChanges.listen((_) => avisos++);

      service.onOrderChanged({'orderId': 'o1', 'totalAmount': 100});
      service.onOrderChanged({'orderId': 'o1', 'status': 'approved'});
      service.onOrderChanged('basura');
      await Future<void>.delayed(Duration.zero);

      expect(avisos, 2);
    });

    test('la ubicación del chofer se lee de lat y lng', () async {
      final out = <DriverLocationUpdate>[];
      service.driverLocationUpdates.listen(out.add);

      service.onDriverLocationUpdate(
          {'orderId': 'o1', 'lat': -27.3, 'lng': -55.9});
      service.onDriverLocationUpdate(
          {'orderId': 'o1', 'latitude': 1, 'longitude': 2});
      await Future<void>.delayed(Duration.zero);

      expect(out, hasLength(1));
      expect(out.single.lat, -27.3);
    });
  });

  group('cortes del servidor', () {
    late OrderTrackingService service;
    setUp(() => service = OrderTrackingService());

    test('con el token vencido reconecta una sola vez', () {
      service.onSessionExpired({});
      expect(
          service.takeReconnectAfterDisconnect('io server disconnect'), isTrue);
      expect(service.takeReconnectAfterDisconnect('io server disconnect'),
          isFalse);
    });

    test('con el acceso revocado no reconecta', () {
      service.onSessionExpired({});
      service.onAccessRevoked({'motivo': 'bloqueo'});
      expect(service.takeReconnectAfterDisconnect('io server disconnect'),
          isFalse);
    });

    test('sin aviso, un corte del servidor no reconecta', () {
      expect(service.takeReconnectAfterDisconnect('io server disconnect'),
          isFalse);
    });

    test('los cortes de red los reintenta socket.io, no la app', () {
      service.onSessionExpired({});
      expect(service.takeReconnectAfterDisconnect('transport close'), isFalse);
    });
  });
}
