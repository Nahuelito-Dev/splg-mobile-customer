import 'dart:developer';

import 'package:splg_customer/core/network/api_client.dart';

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

  /// Lista las direcciones del usuario (`GET /user-address/user/:userId`).
  Future<List<Map<String, dynamic>>> fetchByUser(
      String userId, String token) async {
    try {
      final response = await _apiClient.get('user-address/user/$userId', token);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      log('e in fetchByUser: ${e.toString()}');
    }
    return const [];
  }

  /// Actualiza una dirección (`PATCH /user-address/:id`).
  Future<bool> updateAddress(
      String addressId, Map<String, dynamic> addressData, String token) async {
    try {
      addressData.remove('address_id');
      addressData.remove('user_id');
      final response = await _apiClient.patch(
        'user-address/$addressId',
        addressData,
        token,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      log('e in updateAddress: ${e.toString()}');
    }
    return false;
  }

  /// Marca una dirección como predeterminada
  /// (`PATCH /user-address/:id/set-default`).
  Future<bool> setDefault(String addressId, String token) async {
    try {
      final response = await _apiClient.patch(
        'user-address/$addressId/set-default',
        const {},
        token,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      log('e in setDefault: ${e.toString()}');
    }
    return false;
  }

  /// Elimina una dirección (`DELETE /user-address/:id`).
  Future<bool> deleteAddress(String addressId, String token) async {
    try {
      final response =
          await _apiClient.delete('user-address/$addressId', token);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      log('e in deleteAddress: ${e.toString()}');
    }
    return false;
  }
}
