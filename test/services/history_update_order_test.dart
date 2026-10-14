import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_lib/splg_lib.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

class _Repo implements OrderRepository {
  _Repo(this.results);

  final List<UpdateOrderResult> results;
  final bodies = <Map<String, dynamic>>[];
  final keys = <String>[];

  @override
  Future<UpdateOrderResult> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    bodies.add(orderData);
    keys.add(idempotencyKey);
    return results.removeAt(0);
  }

  @override
  Future<List<Order>> fetchCustomerHistory(String customerId, String token,
          {int limit = 20, int offset = 0}) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUp(() {
    registerServices();
    final customer = locator<CustomerService>() as MockCustomerService;
    when(customer.token).thenAnswer((_) async => 'tok');
    when(customer.customer).thenReturn(customerWith());
  });
  tearDown(() => locator.reset());

  Order edited() => order(
        items: [OrderItem(cylinder: cylinder(price: 1000), quantity: 3)],
        address: addr('a9', 'Mitre 900'),
      ).copyWith(
        paymentMethod: PaymentMethod.online,
        requestedDeliveryDate: DateTime(2026, 10, 20),
        customerNotes: '  portón verde ',
      );

  test('el cuerpo no lleva precios ni cliente: el precio lo pone el back',
      () async {
    final repo = _Repo([UpdateOrderResult(success: true, order: order())]);
    final service = HistoryService(orderRepository: repo);

    await service.updateOrder('o1', edited(), timeSlotId: 's2');

    expect(repo.bodies.single, {
      'addressId': 'a9',
      'paymentMethod': 'transfer',
      'items': [
        {'gasCylinderId': 'g1', 'quantity': 3}
      ],
      'scheduledDate': '2026-10-20',
      'timeSlotId': 's2',
      'notes': 'portón verde',
    });
  });

  test('vaciar las notas también se manda', () async {
    final repo = _Repo([UpdateOrderResult(success: true, order: order())]);
    final service = HistoryService(orderRepository: repo);

    await service.updateOrder('o1', edited().copyWith(customerNotes: ''));

    expect(repo.bodies.single['notes'], '');
  });

  test('el reintento tras una falla de red lleva la misma clave', () async {
    final repo = _Repo([
      const UpdateOrderResult(success: false, retryable: true),
      UpdateOrderResult(success: true, order: order()),
    ]);
    final service = HistoryService(orderRepository: repo);

    await service.updateOrder('o1', edited());
    await service.updateOrder('o1', edited());

    expect(repo.keys[0], repo.keys[1]);
  });

  test('un rechazo de negocio no toca el historial local', () async {
    final repo = _Repo([
      const UpdateOrderResult(
          success: false, rejected: true, message: 'ya fue tomado'),
    ]);
    final service = HistoryService(orderRepository: repo);

    final result = await service.updateOrder('o1', edited());

    expect(result.success, isFalse);
    expect(result.message, 'ya fue tomado');
    expect(service.history, isEmpty);
  });

  test('al guardar, el pedido editado queda en el historial', () async {
    final repo = _Repo([
      UpdateOrderResult(success: true, order: order(id: 'o1', total: 5000))
    ]);
    final service = HistoryService(orderRepository: repo);

    await service.updateOrder('o1', edited());

    expect(service.history.single.total, 5000);
  });

  test('sin notas ni fecha en el pedido editado, no viajan', () async {
    final repo = _Repo([UpdateOrderResult(success: true, order: order())]);
    final service = HistoryService(orderRepository: repo);

    await service.updateOrder('o1',
        order().copyWith(customerNotes: null, requestedDeliveryDate: null));

    expect(repo.bodies.single.containsKey('notes'), isFalse);
    expect(repo.bodies.single.containsKey('scheduledDate'), isFalse);
    expect(repo.bodies.single.containsKey('timeSlotId'), isFalse);
  });

  group('cotización', () {
    test('la de una edición lleva el orderId; la del alta no', () async {
      final log = fakeHttp((_) => const FakeReply(200, {'total': 1}));
      final service = HistoryService(orderRepository: _Repo([]));

      await service.quoteOrder(edited(), orderId: 'o1');
      await service.quoteOrder(edited());

      expect((log[0].body as Map)['orderId'], 'o1');
      expect((log[1].body as Map).containsKey('orderId'), isFalse);
    });
  });
}
