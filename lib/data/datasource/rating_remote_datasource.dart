import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/network/api_error_text.dart';

class RatingRemoteDatasource {
  final _apiClient = ApiClient();

  /// Califica el pedido (`POST /ratings`). El backend deriva a quién se
  /// califica (cliente→chofer) desde el pedido y el emisor sale del token.
  /// Solo pedidos entregados, una vez por lado.
  Future<ApiResult<void>> createRating(
    Map<String, dynamic> body,
    String token,
  ) async {
    try {
      final response = await _apiClient.post('ratings', body, token);
      return response.statusCode == 200 || response.statusCode == 201
          ? const ApiResult.ok()
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  /// `GET /ratings/user/:userId/summary` (CU-065): promedio y cantidad de
  /// calificaciones de un usuario (acá, el chofer del pedido).
  Future<ApiResult<dynamic>> fetchSummary(String userId, String token) async {
    try {
      final response =
          await _apiClient.get('ratings/user/$userId/summary', token);
      return ApiResult.ok(response.data);
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }
}
