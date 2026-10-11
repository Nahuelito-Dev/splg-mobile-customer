import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/cancel_result.dart';

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

  /// [idempotencyKey] identifica la intención de cancelar: se reusa en los
  /// reintentos para que el back no la procese dos veces.
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey,
  );
}
