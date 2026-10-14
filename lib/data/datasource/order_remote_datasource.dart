import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
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
  /// listo (400 de negocio: sin stock, fuera de cobertura).
  Future<ApiResult<dynamic>> quoteOrder(
    Map<String, dynamic> orderData,
    String token,
  ) async {
    try {
      final response = await _apiClient.post('orders/quote', orderData, token);
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in quoteOrder: ${e is DioException ? e.type : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  /// `PATCH /orders/:id`. El back no tiene `PUT` para pedidos, y hoy el `PATCH`
  /// sólo lo permite a admin y super admin: con un cliente responde 403.
  Future<(bool, dynamic)> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
  ) async {
    try {
      final response = await _apiClient.patch(
        'orders/$orderId',
        orderData,
        token,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in updateOrder: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
    }

    return (false, null);
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
