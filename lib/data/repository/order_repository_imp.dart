import 'dart:developer';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/orders_page.dart';

class OrderRepositoryImp implements OrderRepository {
  OrderRepositoryImp(this._remoteDatasource);

  final OrderRemoteDatasource _remoteDatasource;

  @override
  Future<CreateOrderResult> createOrder(
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final result = await _remoteDatasource.createOrder(
        orderData,
        token,
        idempotencyKey,
      );
      if (!result.ok) {
        final conflict =
            result.status == 422 && result.message == kIdempotencyConflictText;
        return CreateOrderResult(
          success: false,
          message: conflict ? kOrderMaybeCreatedText : result.message,
          // Se reintenta con la misma clave si la primera llamada pudo haber
          // llegado: sin respuesta, 5xx, 429, el 409 técnico "en curso" o el
          // 422 de clave ya usada. Un rechazo de negocio (400, 409 de stock)
          // no: hay que cambiar el pedido.
          idempotencyConflict: conflict,
          retryable: result.keepKey ||
              ApiErrorText.isRetryable(result.status) ||
              (result.status == 409 &&
                  result.message == ApiErrorText.inProgress),
        );
      }
      final data = result.data;
      if (data == null) return const CreateOrderResult(success: false);

      // Fallback for APIs that do not return the full created order payload.
      final order = OrderApiMapper.parseOrder(data) ??
          OrderApiMapper.parseOrder(orderData);
      final paymentUrl = OrderApiMapper.extractPaymentUrl(data);

      return CreateOrderResult(
        success: order != null,
        order: order,
        paymentUrl: paymentUrl,
      );
    } catch (e) {
      log('e in createOrder repository: ${e.runtimeType}');
    }

    return const CreateOrderResult(success: false);
  }

  @override
  Future<Order?> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
  ) async {
    try {
      final (success, data) = await _remoteDatasource.updateOrder(
        orderId,
        orderData,
        token,
      );
      if (!success || data == null) return null;

      final order = OrderApiMapper.parseOrder(data);
      if (order != null) return order;

      return OrderApiMapper.parseOrder({
        ...orderData,
        'order_id': orderId,
      });
    } catch (e) {
      log('e in updateOrder repository: ${e.toString()}');
    }

    return null;
  }

  @override
  Future<List<Order>> fetchCustomerHistory(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async =>
      (await fetchCustomerPage(
        customerId,
        token,
        limit: limit,
        offset: offset,
      ))
          .orders;

  @override
  Future<OrdersPage> fetchCustomerPage(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _remoteDatasource.fetchCustomerHistory(
      customerId,
      token,
      limit: limit,
      offset: offset,
    );
    final orders = OrderApiMapper.parseOrders(data);
    final total = data is Map && data['total'] is num
        ? (data['total'] as num).toInt()
        : offset + orders.length;
    return OrdersPage(orders: orders, total: total, offset: offset);
  }

  @override
  Future<Order> fetchOrder(String orderId, String token) async {
    final data = await _remoteDatasource.fetchOrder(orderId, token);
    final order = OrderApiMapper.parseOrder(data);
    if (order == null) throw const FormatException('Pedido ilegible');
    return order;
  }

  @override
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey, {
    String? reason,
  }) async {
    try {
      return await _remoteDatasource.cancelOrder(orderId, token, idempotencyKey,
          reason: reason);
    } catch (e) {
      log('e in cancelOrder repository: ${e.toString()}');
    }

    return const CancelResult.failed();
  }
}
