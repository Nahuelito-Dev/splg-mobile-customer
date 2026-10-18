import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/domain/update_order_result.dart';

abstract interface class OrderRepository {
  /// [idempotencyKey] identifica la intención de crear el pedido: se reusa en
  /// los reintentos para que el back no lo cree dos veces.
  Future<CreateOrderResult> createOrder(
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  );

  /// [idempotencyKey] identifica la edición: se reusa en los reintentos para
  /// que el back no la aplique dos veces.
  Future<UpdateOrderResult> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  );

  /// `GET /orders/delivery-options`: modalidades de entrega para una dirección.
  Future<ApiResult<DeliveryOptions>> deliveryOptions(
      String addressId, String token);

  /// `PATCH /orders/:id/address`. [idempotencyKey] identifica la intención de
  /// cambiar a esa dirección: se reusa en los reintentos.
  Future<UpdateOrderResult> changeOrderAddress(
    String orderId,
    String addressId,
    String token,
    String idempotencyKey, {
    String? reason,
  });

  /// `PATCH /orders/:id/receiver`. [idempotencyKey] identifica la intención de
  /// indicar a ese receptor: se reusa en los reintentos.
  Future<UpdateOrderResult> setOrderReceiver(
    String orderId,
    Map<String, dynamic> receiver,
    String token,
    String idempotencyKey,
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

  /// Como [fetchOrder], con el desglose del total y el estado del cobro.
  Future<OrderDetail> fetchOrderDetail(String orderId, String token);

  /// [idempotencyKey] identifica la intención de cancelar: se reusa en los
  /// reintentos para que el back no la procese dos veces.
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey, {
    String? reason,
  });
}
