import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/my_claim.dart';

class ClaimRemoteDatasource {
  /// El alta responde en snake_case (`claim_id`); el listado, en camelCase.
  static String? claimIdFrom(Object? body) => body is Map
      ? (body['claim_id'] ?? body['claimId'])?.toString()
      : null;

  final _apiClient = ApiClient();

  /// Crea un reclamo (`POST /claims`). Body:
  /// `{ orderId, customerId, reason, description }` (sin `photoUrl`: la foto se
  /// sube aparte). Devuelve el `claimId`.
  Future<ApiResult<String?>> createClaim(
    Map<String, dynamic> body,
    String token,
  ) async {
    try {
      final response = await _apiClient.post('claims', body, token);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult.ok(claimIdFrom(response.data));
      }
      return const ApiResult.fail(
        'No pudimos enviar el reclamo. Probá de nuevo.',
      );
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  /// Mis reclamos (`GET /claims/mine`): del más nuevo al más viejo, paginado;
  /// el total viaja en `X-Total-Count`.
  Future<ApiResult<ClaimsPage>> fetchMine(
    String token, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        'claims/mine?limit=$limit&offset=$offset',
        token,
      );
      final data = response.data;
      if (response.statusCode == 200 && data is List) {
        final claims = data
            .whereType<Map>()
            .map((e) => MyClaim.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final total =
            int.tryParse(response.headers.value('x-total-count') ?? '') ??
                claims.length;
        return ApiResult.ok(ClaimsPage(claims: claims, total: total));
      }
      return const ApiResult.fail('No pudimos cargar tus reclamos.');
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }
}
