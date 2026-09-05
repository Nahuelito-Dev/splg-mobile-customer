import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';

class CreateOrderUseCase {
  CreateOrderUseCase(this._orderRepository);

  final OrderRepository _orderRepository;

  Future<CreateOrderResult> call(
    Map<String, dynamic> orderData,
    String token,
  ) async =>
      await _orderRepository.createOrder(orderData, token);
}
