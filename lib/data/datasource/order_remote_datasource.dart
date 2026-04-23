import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';

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

  Future<bool> updateOrderStatus(
    String orderId,
    String status,
    String token,
  ) async {
    try {
      final response = await _apiClient.patch(
        'orders/$orderId/status',
        {'status': status},
        token,
      );

      return response.statusCode == 200;
    } catch (e) {
      log('e in updateOrderStatus: ${e.toString()}');
    }

    return false;
  }
}
