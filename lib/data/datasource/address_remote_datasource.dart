import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';

class AddressRemoteDataSource {
  final _apiClient = ApiClient();

  Future<bool> createAddress(
      Map<String, dynamic> addressData, String token, String userId) async {
    try {
      addressData.remove('address_id');
      addressData['user_id'] = userId;

      final response = await _apiClient.post(
        'user-address',
        addressData,
        token,
      );
      return response.statusCode == 201;
    } catch (e) {
      log(e.toString());
    }

    return false;
  }
}
