import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';

class RatingRemoteDatasource {
  final _apiClient = ApiClient();

  /// Califica el pedido (`POST /ratings`). El backend deriva a quién se
  /// califica (cliente→chofer) desde el pedido y el emisor sale del token.
  /// Solo pedidos entregados, una vez por lado.
  Future<bool> createRating(
    Map<String, dynamic> body,
    String token,
  ) async {
    try {
      final response = await _apiClient.post('ratings', body, token);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      log('e in createRating: ${e.toString()}');
    }
    return false;
  }
}
