import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_lib/splg_lib.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

class _FakeRepository implements OrderRepository {
  _FakeRepository(this.cancelResult);

  final CancelResult cancelResult;
  int historyFetches = 0;

  @override
  Future<CancelResult> cancelOrder(
          String orderId, String token, String idempotencyKey,
          {String? reason}) async =>
      cancelResult;

  @override
  Future<List<Order>> fetchCustomerHistory(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async {
    historyFetches++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Repositorio con las respuestas en manos del test (Completers).
class _SlowRepository implements OrderRepository {
  Completer<List<Order>>? history;
  Completer<CreateOrderResult>? create;
  Completer<OrdersPage>? page;

  @override
  Future<List<Order>> fetchCustomerHistory(String customerId, String token,
          {int limit = 20, int offset = 0}) =>
      history!.future;

  @override
  Future<CreateOrderResult> createOrder(
          Map<String, dynamic> orderData, String token) =>
      create!.future;

  @override
  Future<OrdersPage> fetchCustomerPage(String customerId, String token,
          {int limit = 20, int offset = 0}) =>
      page!.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Order _o(String id) => Order(
      id: id,
      items: [],
      total: 0,
      status: OrderStatus.pending,
      createdAt: DateTime(2026, 10, 10),
      paymentMethod: PaymentMethod.cash,
    );

void main() {
  group('HistoryServiceTest -', () {
    setUp(() {
      registerServices();
      final customer = locator<CustomerService>() as MockCustomerService;
      when(customer.token).thenAnswer((_) async => 'tok');
      when(customer.customer).thenReturn(Customer(
        customerId: 'c1',
        fullName: 'Cliente',
        email: 'c@splg.com',
        phoneNumber: '1',
        blocked: false,
      ));
    });
    tearDown(() => locator.reset());

    test('si el back rechaza ("ya finalizado") refresca el historial',
        () async {
      final repo = _FakeRepository(const CancelResult.rejected(
          'No se puede cancelar un pedido finalizado'));
      final service = HistoryService(orderRepository: repo);

      final result = await service.cancelOrder('o1');

      expect(result.isRejected, isTrue);
      expect(repo.historyFetches, 1);
    });

    test('un fallo de red no refresca (el pedido no cambió)', () async {
      final repo = _FakeRepository(const CancelResult.failed());
      final service = HistoryService(orderRepository: repo);

      await service.cancelOrder('o1');

      expect(repo.historyFetches, 0);
    });

    test('al cancelar con éxito también refresca', () async {
      final repo = _FakeRepository(const CancelResult.ok());
      final service = HistoryService(orderRepository: repo);

      await service.cancelOrder('o1');

      expect(repo.historyFetches, 1);
    });

    test('un poll que vuelve después de crear el pedido no lo pisa', () async {
      final repo = _SlowRepository()
        ..history = Completer()
        ..create = Completer();
      final service = HistoryService(orderRepository: repo);

      final poll = service.refreshHistory(limit: 10); // sale antes del POST
      await Future<void>.delayed(Duration.zero);
      final creating = service.createOrder(_o('nuevo'));
      await Future<void>.delayed(Duration.zero);
      repo.create!
          .complete(CreateOrderResult(success: true, order: _o('nuevo')));
      await creating;
      repo.history!.complete([_o('viejo')]); // la respuesta es anterior al alta
      await poll;

      expect(service.history.map((o) => o.id), ['nuevo']);
    });

    test('una consulta en vuelo al cerrar sesión no vuelve a llenar la lista',
        () async {
      final repo = _SlowRepository()..history = Completer();
      final service = HistoryService(orderRepository: repo);

      final poll = service.refreshHistory(limit: 10);
      await Future<void>.delayed(Duration.zero);
      service.reset();
      repo.history!.complete([_o('del-usuario-anterior')]);
      await poll;

      expect(service.history, isEmpty);
      expect(service.hasPendingOrder, isFalse);
    });

    test('un alta que vuelve después de cerrar sesión no entra a la lista',
        () async {
      final repo = _SlowRepository()..create = Completer();
      final service = HistoryService(orderRepository: repo);

      final creating = service.createOrder(_o('x'));
      await Future<void>.delayed(Duration.zero);
      service.reset();
      repo.create!.complete(CreateOrderResult(success: true, order: _o('x')));
      await creating;

      expect(service.history, isEmpty);
    });

    test('una página de Mis pedidos de la sesión anterior se descarta',
        () async {
      final repo = _SlowRepository()..page = Completer();
      final service = HistoryService(orderRepository: repo);

      final page = service.fetchOrdersPage();
      await Future<void>.delayed(Duration.zero);
      service.reset();
      repo.page!.complete(OrdersPage(orders: [_o('a')], total: 1, offset: 0));

      await expectLater(page, throwsA(isA<LoadFailure>()));
    });
  });
}
