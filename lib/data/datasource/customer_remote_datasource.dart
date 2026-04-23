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
}
