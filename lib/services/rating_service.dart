import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/data/datasource/rating_remote_datasource.dart';
import 'package:jennigas_customer/services/customer_service.dart';

/// Calificaciones del cliente hacia el chofer, una por pedido entregado.
class RatingService {
  final _datasource = RatingRemoteDatasource();
  final _customerService = locator<CustomerService>();

  /// Envía la calificación del chofer para [orderId]. Devuelve `true` si el
  /// backend la registró. `stars` 1..5, `comment` opcional.
  Future<bool> rateDriver({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final token = await _customerService.token;
    if (token == null) return false;

    final body = <String, dynamic>{'orderId': orderId, 'stars': stars};
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) body['comment'] = trimmed;

    return _datasource.createRating(body, token);
  }
}
