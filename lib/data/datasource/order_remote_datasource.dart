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

  Future<(bool, dynamic)> fetchCustomerHistory(
    String customerId,
    String token, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        'orders/customer/$customerId?limit=$limit&offset=$offset',
        token,
      );

      if (response.statusCode == 200) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in fetchCustomerHistory: ${e.toString()}');
    }

    return (false, null);
  }

  /// `PATCH /orders/:id/cancel`: el cliente no puede usar `/status` (sólo
  /// chofer y admin). Idempotente por `Idempotency-Key`, que llega de afuera
  /// para que los reintentos de una misma intención lleven la misma clave.
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey,
  ) async {
    try {
      final response = await _apiClient.patch(
        'orders/$orderId/cancel',
        {},
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
