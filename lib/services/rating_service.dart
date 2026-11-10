import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/rating_remote_datasource.dart';
import 'package:splg_customer/domain/rating_summary.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Calificaciones del cliente hacia el chofer, una por pedido entregado.
class RatingService {
  final _datasource = RatingRemoteDatasource();
  final _customerService = locator<CustomerService>();

  /// Envía la calificación del chofer para [orderId]. `stars` 1..5, `comment`
  /// opcional. Un 409 ("Ya calificaste este pedido") llega con su mensaje.
  Future<ApiResult<void>> rateDriver({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);

    final body = <String, dynamic>{'orderId': orderId, 'stars': stars};
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) body['comment'] = trimmed;

    return _datasource.createRating(body, token);
  }

  /// Promedio de calificaciones de un usuario (CU-065), acá el chofer del
  /// pedido. Un error vuelve con el texto y el código del back.
  Future<ApiResult<RatingSummary>> summaryOf(String userId) async {
    final token = await _customerService.token;
    if (token == null) {
      return const ApiResult.fail(ApiErrorText.sessionExpired, status: 401);
    }
    final result = await _datasource.fetchSummary(userId, token);
    if (!result.ok) {
      return ApiResult.fail(result.message ?? ApiErrorText.generic,
          status: result.status);
    }
    final summary = RatingSummary.fromJson(result.data);
    if (summary == null) return const ApiResult.fail(ApiErrorText.generic);
    return ApiResult.ok(summary);
  }
}
