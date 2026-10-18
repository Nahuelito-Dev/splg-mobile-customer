import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/repository/order_repository_imp.dart';

import '../helpers/fake_http.dart';

void main() {
  const pedido = {'addressId': 'a1', 'items': []};

  group('POST /orders', () {
    test('manda la Idempotency-Key que le pasan', () async {
      final log = fakeHttp((_) => const FakeReply(201, {'order_id': 'o1'}));

      final result = await OrderRemoteDatasource().createOrder(
        pedido,
        'tok',
        'clave-1',
      );

      expect(result.ok, isTrue);
      expect(log.single.method, 'POST');
      expect(log.single.path, 'orders');
      expect(log.single.headers['Idempotency-Key'], 'clave-1');
    });

    test('un 400 de negocio vuelve con el mensaje del back', () async {
      fakeHttp((_) => const FakeReply(400, {
            'statusCode': 400,
            'message': 'La dirección está fuera de la zona de cobertura',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.createOrder(pedido, 'tok', 'k');

      expect(result.success, isFalse);
      expect(result.message, 'La dirección está fuera de la zona de cobertura');
      expect(result.retryable, isFalse);
    });

    test('un 409 de stock vuelve con el mensaje del back', () async {
      fakeHttp((_) => const FakeReply(
          409, {'message': 'Stock insuficiente para Garrafa 10kg'}));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.createOrder(pedido, 'tok', 'k');

      expect(result.message, 'Stock insuficiente para Garrafa 10kg');
      expect(result.retryable, isFalse);
    });

    test('sin conexión se dice como tal y se puede reintentar', () async {
      fakeHttp((_) => const FakeReply.networkError());
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.createOrder(pedido, 'tok', 'k');

      expect(result.message, contains('conexión'));
      expect(result.retryable, isTrue);
    });

    test('un 500 no muestra el texto técnico y se puede reintentar', () async {
      fakeHttp(
          (_) => const FakeReply(500, {'message': 'Internal server error'}));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.createOrder(pedido, 'tok', 'k');

      expect(result.message, isNot(contains('Internal')));
      expect(result.retryable, isTrue);
    });
  });

  group('PATCH /orders/:id', () {
    const orderJson = {'order_id': 'o1', 'total_amount': 5000};

    test('manda PATCH con la Idempotency-Key y el cuerpo, sin caer a un PUT',
        () async {
      final log = fakeHttp((_) => const FakeReply(200, orderJson));

      final result = await OrderRemoteDatasource()
          .updateOrder('o1', {'notes': 'x'}, 'tok', 'clave-9');

      expect(result.ok, isTrue);
      expect(log.map((r) => r.method), ['PATCH']);
      expect(log.single.path, 'orders/o1');
      expect(log.single.headers['Idempotency-Key'], 'clave-9');
      expect(log.single.body, {'notes': 'x'});
    });

    test('un 409 del back vuelve con su mensaje, no con "Verificá tu conexión"',
        () async {
      fakeHttp((_) => const FakeReply(409, {
            'statusCode': 409,
            'message':
                'El pedido ya fue tomado por un repartidor: no se puede modificar',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {'notes': 'x'}, 'tok', 'k');

      expect(result.success, isFalse);
      expect(result.rejected, isTrue);
      expect(result.retryable, isFalse);
      expect(result.message,
          'El pedido ya fue tomado por un repartidor: no se puede modificar');
    });

    test('409 por la seña pagada: se muestra el mensaje del back', () async {
      fakeHttp((_) => const FakeReply(409, {
            'statusCode': 409,
            'message':
                'El total no puede quedar por debajo de la seña ya pagada',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect(result.rejected, isTrue);
      expect(result.message, contains('seña'));
    });

    test('red caída o 5xx: se puede reintentar con la misma clave', () async {
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      fakeHttp((_) => const FakeReply.networkError());
      final offline = await repo.updateOrder('o1', {}, 'tok', 'k');
      fakeHttp((_) => const FakeReply(503, {'message': 'x'}));
      final down = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect((offline.retryable, offline.rejected), (true, false));
      expect((down.retryable, down.rejected), (true, false));
    });

    test('409 "en curso" de la idempotencia: reintentable, no es un rechazo',
        () async {
      fakeHttp((_) => const FakeReply(409, {
            'message': 'Request en curso con la misma Idempotency-Key',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect((result.retryable, result.rejected), (true, false));
    });

    test('404 porque el pedido ya no existe: es un rechazo, texto propio',
        () async {
      fakeHttp((_) => const FakeReply(404, {
            'statusCode': 404,
            'message': 'Order with ID: o1 not found',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect(result.rejected, isTrue);
      expect(result.message, 'Este pedido ya no está disponible.');
    });

    test('404 "Dirección no encontrada": mensaje del back, no es rechazo',
        () async {
      fakeHttp((_) => const FakeReply(404, {
            'statusCode': 404,
            'message': 'Dirección no encontrada',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect(result.rejected, isFalse);
      expect(result.message, 'Dirección no encontrada');
    });

    test('422 de la clave ya usada: el primer envío llegó', () async {
      fakeHttp((_) => const FakeReply(422, {
            'message':
                'Esa clave de idempotencia ya se usó con otros datos del pedido',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect(result.idempotencyConflict, isTrue);
      expect(result.retryable, isFalse);
    });

    test('éxito: devuelve el pedido con el total del back', () async {
      fakeHttp((_) => const FakeReply(200, orderJson));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final result = await repo.updateOrder('o1', {}, 'tok', 'k');

      expect(result.success, isTrue);
      expect(result.order!.total, 5000);
    });
  });

  group('GET /orders/:id con desglose', () {
    test('lee los recargos y el cobro del cuerpo', () async {
      fakeHttp((_) => const FakeReply(200, {
            'order_id': 'o1',
            'total_amount': 17380,
            'payment_method': 'online',
            'paymentStatus': 'pending',
            'editable': true,
            'subtotal_items': 14900,
            'zone_surcharge': {'name': 'Villa Cabello', 'amount': 900},
            'scheduledDate': '2026-10-20',
          }));
      final repo = OrderRepositoryImp(OrderRemoteDatasource());

      final detail = await repo.fetchOrderDetail('o1', 'tok');

      expect(detail.order.total, 17380);
      expect(detail.breakdown!.zoneSurcharge, 900);
      expect(detail.breakdown!.zoneName, 'Villa Cabello');
      expect(detail.breakdown!.paymentSurcharge, 1580);
      expect(detail.breakdown!.scheduledDate, '2026-10-20');
      expect(detail.breakdown!.editable, isTrue);
    });
  });

  group('GET /orders/:id/refunds/mine', () {
    test('pide la ruta del pedido con el token y devuelve la lista', () async {
      final log = fakeHttp((_) => const FakeReply(200, [
            {
              'kind': 'full',
              'amount': 15800,
              'status': 'failed',
              'requestedAt': '2026-10-18T04:09:23.013Z',
              'completedAt': null,
            }
          ]));

      final result = await OrderRemoteDatasource().fetchMyRefunds('o1', 'tok');

      expect(result.ok, isTrue);
      expect(log.single.method, 'GET');
      expect(log.single.path, 'orders/o1/refunds/mine');
      expect(log.single.headers['Authorization'], contains('tok'));
    });

    test('un pedido ajeno (404) vuelve como fallo, no como lista vacía',
        () async {
      fakeHttp((_) => const FakeReply(404, {
            'statusCode': 404,
            'message': 'Order with ID: o1 not found',
          }));

      final result = await OrderRemoteDatasource().fetchMyRefunds('o1', 'tok');

      expect(result.ok, isFalse);
      expect(result.status, 404);
    });
  });
}
