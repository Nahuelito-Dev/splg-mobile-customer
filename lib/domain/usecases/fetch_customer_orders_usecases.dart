import 'package:jennygas_lib/domain/order.dart';
import 'package:jennigas_customer/domain/repository/order_repository.dart';

class FetchCustomerOrdersUseCase {
  FetchCustomerOrdersUseCase(this._orderRepository);

  final OrderRepository _orderRepository;

  Future<List<Order>> call(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async =>
      await _orderRepository.fetchCustomerHistory(
        customerId,
        token,
        limit: limit,
        offset: offset,
      );
}
