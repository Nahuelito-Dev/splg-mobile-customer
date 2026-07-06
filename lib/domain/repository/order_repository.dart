import 'package:jennygas_lib/domain/order.dart';
import 'package:jennigas_customer/domain/create_order_result.dart';

abstract interface class OrderRepository {
  Future<CreateOrderResult> createOrder(
    Map<String, dynamic> orderData,
    String token,
  );

  Future<Order?> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
  );

  Future<List<Order>> fetchCustomerHistory(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  });

  Future<bool> updateOrderStatus(
    String orderId,
    String status,
    String token,
  );
}
