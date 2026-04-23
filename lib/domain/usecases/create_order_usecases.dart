import 'package:jennygas_lib/domain/order.dart';
import 'package:jennigas_customer/domain/repository/order_repository.dart';

class CreateOrderUseCase {
  CreateOrderUseCase(this._orderRepository);

  final OrderRepository _orderRepository;

  Future<Order?> call(
    Map<String, dynamic> orderData,
    String token,
  ) async =>
      await _orderRepository.createOrder(orderData, token);
}
