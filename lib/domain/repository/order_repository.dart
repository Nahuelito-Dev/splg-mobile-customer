import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/orders_page.dart';

abstract interface class OrderRepository {
  /// [idempotencyKey] identifica la intención de crear el pedido: se reusa en
  /// los reintentos para que el back no lo cree dos veces.
  Future<CreateOrderResult> createOrder(
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
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

  /// Una página del historial con el total; lanza ante cualquier error.
  Future<OrdersPage> fetchCustomerPage(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  });

  /// `GET /orders/:id`; lanza ante cualquier error.
  Future<Order> fetchOrder(String orderId, String token);

  /// [idempotencyKey] identifica la intención de cancelar: se reusa en los
  /// reintentos para que el back no la procese dos veces.
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey, {
    String? reason,
  });
}
