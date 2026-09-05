import 'dart:developer';

import 'package:splg_customer/core/network/api_client.dart';

class ClaimRemoteDatasource {
  final _apiClient = ApiClient();

  /// Crea un reclamo (`POST /claims`). Body:
  /// `{ orderId, customerId, reason, description, photoUrl? }`.
  Future<bool> createClaim(
    Map<String, dynamic> body,
    String token,
  ) async {
    try {
      final response = await _apiClient.post('claims', body, token);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      log('e in createClaim: ${e.toString()}');
    }
    return false;
  }
}
