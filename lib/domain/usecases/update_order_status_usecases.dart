import 'package:splg_customer/domain/repository/order_repository.dart';

class UpdateOrderStatusUseCase {
  UpdateOrderStatusUseCase(this._orderRepository);

  final OrderRepository _orderRepository;

  Future<bool> call(
    String orderId,
    String status,
    String token,
  ) async =>
      await _orderRepository.updateOrderStatus(orderId, status, token);
}
