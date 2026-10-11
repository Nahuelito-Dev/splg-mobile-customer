import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/claim_remote_datasource.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Reclamos del cliente: alta sobre un pedido (`POST /claims`) y listado de
/// los propios (`GET /claims/mine`).
class ClaimService {
  final _datasource = ClaimRemoteDatasource();
  final _customerService = locator<CustomerService>();

  /// Crea un reclamo para [orderId]. `reason` es el motivo (etiqueta corta) y
  /// `description` el detalle.
  Future<ApiResult<void>> createClaim({
    required String orderId,
    required String reason,
    required String description,
  }) async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);

    return _datasource.createClaim({
      'orderId': orderId,
      'customerId': _customerService.customer.customerId,
      'reason': reason,
      'description': description,
    }, token);
  }

  Future<ApiResult<ClaimsPage>> fetchMine({
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    return _datasource.fetchMine(token, limit: limit, offset: offset);
  }
}
