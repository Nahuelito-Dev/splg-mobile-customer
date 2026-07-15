import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';

class CustomerRemoteDatasource {
  final _apiClient = ApiClient();

  Future<(bool, dynamic)> createCustomer(
      Map<String, dynamic> customerData) async {
    try {
      final response = await _apiClient.post(
        'users/customer-registration',
        customerData,
      );

      if (response.statusCode == 201) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in createCustomer: ${e.toString()}');
    }

    return (false, null);
  }

  Future<(bool, dynamic)> fetchCustomerByEmail(
      String email, String token) async {
    try {
      final response = await _apiClient.get('users/email/$email', token);

      if (response.statusCode == 200) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in fetchCustomerByEmail: ${e.toString()}');
    }

    return (false, null);
  }

  /// Actualiza datos del propio usuario (`PATCH /users/:id`). Solo se mandan
  /// los campos a cambiar (p.ej. full_name, phone_number).
  Future<bool> updateUser(
      String userId, Map<String, dynamic> data, String token) async {
    try {
      final response = await _apiClient.patch('users/$userId', data, token);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      log('e in updateUser: ${e.toString()}');
    }
    return false;
  }
}
