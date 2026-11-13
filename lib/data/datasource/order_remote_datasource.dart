import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/domain/cancel_result.dart';

class OrderRemoteDatasource {
  final _apiClient = ApiClient();

  /// `POST /orders`, idempotente por `Idempotency-Key`: [idempotencyKey]
  /// llega de afuera para que los reintentos de una misma intención lleven la
  /// misma clave. Un error vuelve como `ApiResult.fail` con el texto listo.
  Future<ApiResult<dynamic>> createOrder(
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final response = await _apiClient.post(
        'orders',
        orderData,
        token,
        {'Idempotency-Key': idempotencyKey},
      );
      final status = response.statusCode;
      if (status == 201 || status == 200) {
        return ApiResult.ok(response.data);
      }
      return ApiResult.fromError(DioException(
        requestOptions: response.requestOptions,
        response: response,
      ));
    } catch (e) {
      log('e in createOrder: ${e is DioException ? e.type : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `POST /orders/quote`: el total que cobraría el alta con este mismo cuerpo
  /// (no escribe nada). Un error vuelve como `ApiResult.fail` con el texto
  /// listo (400 de negocio: sin stock, fuera de cobertura). Con
  /// [distributorId] cotiza en esa distribuidora (`X-Distributor`) en vez de
  /// la de la app.
  Future<ApiResult<dynamic>> quoteOrder(
    Map<String, dynamic> orderData,
    String token, {
    String? distributorId,
  }) async {
    try {
      final response = await _apiClient.post('orders/quote', orderData, token,
          {if (distributorId != null) 'X-Distributor': distributorId});
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in quoteOrder: ${e is DioException ? e.type : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `GET /orders/:id/status-history` (CU-170): del más viejo al más nuevo.
  Future<ApiResult<dynamic>> fetchStatusHistory(
    String orderId,
    String token,
  ) async {
    try {
      final response =
          await _apiClient.get('orders/$orderId/status-history', token);
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in fetchStatusHistory: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `POST /orders/express/quote` (CU-147): vista previa de la compra express
  /// con la dirección predeterminada y la garrafa habitual. No escribe nada.
  Future<ApiResult<dynamic>> expressQuote(
    Map<String, dynamic> body,
    String token,
  ) async {
    try {
      final response =
          await _apiClient.post('orders/express/quote', body, token);
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in expressQuote: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `POST /orders/express` (CU-147), idempotente por `Idempotency-Key`.
  Future<ApiResult<dynamic>> expressBuy(
    Map<String, dynamic> body,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final response = await _apiClient.post(
          'orders/express', body, token, {'Idempotency-Key': idempotencyKey});
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in expressBuy: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `PATCH /orders/:id`: el cliente dueño edita su pedido mientras está
  /// pendiente y sin repartidor. Idempotente por `Idempotency-Key`, que llega
  /// de afuera para que los reintentos de una misma edición lleven la misma
  /// clave. Un error vuelve como `ApiResult.fail` con el texto listo.
  Future<ApiResult<dynamic>> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final response = await _apiClient.patch(
        'orders/$orderId',
        orderData,
        token,
        {'Idempotency-Key': idempotencyKey},
      );
      final status = response.statusCode;
      if (status == 200 || status == 204) return ApiResult.ok(response.data);
      return ApiResult.fromError(DioException(
        requestOptions: response.requestOptions,
        response: response,
      ));
    } catch (e) {
      log('e in updateOrder: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return _notFoundOf(e) ?? ApiResult.fromError(e);
    }
  }

  /// `GET /orders/delivery-options?addressId=`: modalidades de entrega que
  /// ofrece la distribuidora para esa dirección (no escribe nada). Un error
  /// vuelve como `ApiResult.fail` con el texto listo.
  Future<ApiResult<dynamic>> deliveryOptions(
    String addressId,
    String token,
  ) async {
    try {
      final response = await _apiClient.get(
        'orders/delivery-options?addressId=${Uri.encodeQueryComponent(addressId)}',
        token,
      );
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in deliveryOptions: ${e is DioException ? e.type : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `PATCH /orders/:id/address` (CU-127): el cliente dueño elige otra de sus
  /// direcciones mientras el pedido está pendiente o aceptado. Idempotente por
  /// `Idempotency-Key`. Responde el pedido completo.
  Future<ApiResult<dynamic>> changeOrderAddress(
    String orderId,
    String addressId,
    String token,
    String idempotencyKey, {
    String? reason,
  }) =>
      _patchOrder(
        'orders/$orderId/address',
        {
          'addressId': addressId,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
        token,
        idempotencyKey,
      );

  /// `PATCH /orders/:id/receiver` (CU-128): quién recibe el pedido. Reemplaza lo
  /// anterior. Idempotente por `Idempotency-Key`. Responde el pedido completo.
  Future<ApiResult<dynamic>> setOrderReceiver(
    String orderId,
    Map<String, dynamic> receiver,
    String token,
    String idempotencyKey,
  ) =>
      _patchOrder('orders/$orderId/receiver', receiver, token, idempotencyKey);

  Future<ApiResult<dynamic>> _patchOrder(
    String path,
    Map<String, dynamic> body,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final response = await _apiClient.patch(
        path,
        body,
        token,
        {'Idempotency-Key': idempotencyKey},
      );
      final status = response.statusCode;
      if (status == 200 || status == 204) return ApiResult.ok(response.data);
      return ApiResult.fromError(DioException(
        requestOptions: response.requestOptions,
        response: response,
      ));
    } catch (e) {
      log('e in $path: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return _notFoundOf(e) ?? ApiResult.fromError(e);
    }
  }

  /// Un 404 del PATCH: o el pedido ya no existe (texto propio, el del back es
  /// genérico) o es otro recurso ("Dirección no encontrada") y vale su mensaje.
  ApiResult<dynamic>? _notFoundOf(Object e) {
    if (e is! DioException || e.response?.statusCode != 404) return null;
    final data = e.response?.data;
    final message = data is Map && data['message'] is String
        ? (data['message'] as String).trim()
        : '';
    if (message.isEmpty ||
        message == kBackOrderNotFoundText ||
        message.startsWith(kLegacyBackOrderNotFoundPrefix)) {
      return const ApiResult.fail(kOrderGoneText, status: 404);
    }
    return ApiResult.fail(message, status: 404);
  }

  /// `GET /orders/customer/:userId?limit&offset`. Ante cualquier error
  /// (red, 4xx, 5xx) lanza: una falla no es una lista vacía.
  Future<dynamic> fetchCustomerHistory(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      'orders/customer/$customerId?limit=$limit&offset=$offset',
      token,
    );
    return response.data;
  }

  /// `GET /orders/:id`. Lanza ante cualquier error.
  Future<dynamic> fetchOrder(String orderId, String token) async {
    final response = await _apiClient.get('orders/$orderId', token);
    return response.data;
  }

  /// `GET /orders/:id/refunds/mine`: las devoluciones del pago del pedido del
  /// cliente dueño. Un error vuelve como `ApiResult.fail`.
  Future<ApiResult<dynamic>> fetchMyRefunds(
    String orderId,
    String token,
  ) async {
    try {
      final response =
          await _apiClient.get('orders/$orderId/refunds/mine', token);
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in fetchMyRefunds: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `PATCH /orders/:id/cancel`: el cliente no puede usar `/status` (sólo
  /// chofer y admin). Idempotente por `Idempotency-Key`, que llega de afuera
  /// para que los reintentos de una misma intención lleven la misma clave.
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey, {
    String? reason,
  }) async {
    try {
      final response = await _apiClient.patch(
        'orders/$orderId/cancel',
        {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim()
        },
        token,
        {'Idempotency-Key': idempotencyKey},
      );

      return CancelResult.fromResponse(response.statusCode, response.data);
    } on DioException catch (e) {
      log('e in cancelOrder: ${e.toString()}');
      return CancelResult.fromResponse(
          e.response?.statusCode, e.response?.data);
    } catch (e) {
      log('e in cancelOrder: ${e.toString()}');
    }

    return const CancelResult.failed();
  }
}
