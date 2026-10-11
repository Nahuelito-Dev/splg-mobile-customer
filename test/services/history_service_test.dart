import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/cancel_result.dart';
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
          String orderId, String token, String idempotencyKey) async =>
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
  });
}
