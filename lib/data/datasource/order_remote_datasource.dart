import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/domain/cancel_result.dart';

class OrderRemoteDatasource {
  final _apiClient = ApiClient();

  Future<(bool, dynamic)> createOrder(
    Map<String, dynamic> orderData,
    String token,
  ) async {
    try {
      final response = await _apiClient.post('orders', orderData, token);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in createOrder: ${e.toString()}');
    }

    return (false, null);
  }

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
      log('e in updateOrder (patch): ${e.toString()}');
    }

    try {
      final response = await _apiClient.put(
        'orders/$orderId',
        orderData,
        token,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in updateOrder (put): ${e.toString()}');
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
