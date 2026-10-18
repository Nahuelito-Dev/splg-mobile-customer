import 'dart:developer';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/domain/update_order_result.dart';

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
        final expressReason = _expressUnavailableReason(result);
        return CreateOrderResult(
          success: false,
          message: conflict
              ? kOrderMaybeCreatedText
              : expressReason != null
                  ? expressUnavailableText(expressReason)
                  : result.message,
          expressUnavailableReason: expressReason,
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
  Future<UpdateOrderResult> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final result = await _remoteDatasource.updateOrder(
        orderId,
        orderData,
        token,
        idempotencyKey,
      );
      return _updateResult(result);
    } catch (e) {
      log('e in updateOrder repository: ${e.runtimeType}');
    }

    return const UpdateOrderResult(
        success: false, message: ApiErrorText.generic);
  }

  /// Resultado de un PATCH sobre el pedido (edición, dirección, receptor).
  UpdateOrderResult _updateResult(ApiResult<dynamic> result) {
    if (!result.ok) {
      final conflict =
          result.status == 422 && result.message == kIdempotencyConflictText;
      return UpdateOrderResult(
        success: false,
        message: conflict ? kOrderMaybeEditedText : result.message,
        idempotencyConflict: conflict,
        // Se reintenta con la misma clave si la primera llamada pudo haber
        // llegado (sin respuesta, 5xx, 429, 409 "en curso"). Un 400/409 de
        // negocio no: hay que cambiar la edición o el pedido ya cambió.
        retryable: result.keepKey && !conflict,
        // 409 de negocio, o el pedido ya no existe (404): el estado cambió.
        rejected: (result.status == 409 &&
                result.message != ApiErrorText.inProgress) ||
            (result.status == 404 && result.message == kOrderGoneText),
      );
    }
    // Aplicó el cambio aunque la respuesta no se pueda leer: sin pedido, quien
    // llama lo relee.
    return UpdateOrderResult(
        success: true, order: OrderApiMapper.parseOrder(result.data));
  }

  /// El `reason` de un 409 `EXPRESS_NOT_AVAILABLE`, o null si el error es otro.
  String? _expressUnavailableReason(ApiResult<dynamic> result) {
    final body = result.body;
    if (result.status != 409 || body is! Map) return null;
    if (body['code'] != 'EXPRESS_NOT_AVAILABLE') return null;
    return body['reason']?.toString() ?? 'unknown';
  }

  @override
  Future<ApiResult<DeliveryOptions>> deliveryOptions(
      String addressId, String token) async {
    final result = await _remoteDatasource.deliveryOptions(addressId, token);
    if (!result.ok) {
      return ApiResult.fail(result.message ?? ApiErrorText.generic,
          status: result.status);
    }
    final options = DeliveryOptions.fromJson(result.data);
    if (options == null) return const ApiResult.fail(ApiErrorText.generic);
    return ApiResult.ok(options);
  }

  @override
  Future<UpdateOrderResult> changeOrderAddress(
    String orderId,
    String addressId,
    String token,
    String idempotencyKey, {
    String? reason,
  }) async {
    try {
      return _updateResult(await _remoteDatasource.changeOrderAddress(
          orderId, addressId, token, idempotencyKey,
          reason: reason));
    } catch (e) {
      log('e in changeOrderAddress repository: ${e.runtimeType}');
    }
    return const UpdateOrderResult(
        success: false, message: ApiErrorText.generic);
  }

  @override
  Future<UpdateOrderResult> setOrderReceiver(
    String orderId,
    Map<String, dynamic> receiver,
    String token,
    String idempotencyKey,
  ) async {
    try {
      return _updateResult(await _remoteDatasource.setOrderReceiver(
          orderId, receiver, token, idempotencyKey));
    } catch (e) {
      log('e in setOrderReceiver repository: ${e.runtimeType}');
    }
    return const UpdateOrderResult(
        success: false, message: ApiErrorText.generic);
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
  Future<OrderDetail> fetchOrderDetail(String orderId, String token) async {
    final data = await _remoteDatasource.fetchOrder(orderId, token);
    final order = OrderApiMapper.parseOrder(data);
    if (order == null) throw const FormatException('Pedido ilegible');
    return OrderDetail(order, OrderBreakdown.fromJson(data));
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
