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
    test('un rechazo no cae a un PUT que el back no tiene', () async {
      final log = fakeHttp((_) => const FakeReply(403, {'message': 'x'}));

      final (ok, _) = await OrderRemoteDatasource()
          .updateOrder('o1', {'notes': 'x'}, 'tok');

      expect(ok, isFalse);
      expect(log.map((r) => r.method), ['PATCH']);
      expect(log.single.path, 'orders/o1');
    });
  });
}
