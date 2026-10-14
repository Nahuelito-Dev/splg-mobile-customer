import 'dart:convert';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/idempotency.dart';
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

  /// Una clave por reclamo (pedido, motivo y detalle): el reintento tras una
  /// falla de red, 5xx o 429 lleva la misma y el back no lo duplica.
  final _keys = IdempotencyKeys();

  /// Crea un reclamo para [orderId]. `reason` es el motivo (etiqueta corta) y
  /// `description` el detalle. Devuelve el id del reclamo creado.
  Future<ApiResult<String?>> createClaim({
    required String orderId,
    required String reason,
    required String description,
  }) async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);

    final body = {
      'orderId': orderId,
      'customerId': _customerService.customer.customerId,
      'reason': reason,
      'description': description,
    };
    final intention = jsonEncode(body);
    final result =
        await _datasource.createClaim(body, token, _keys.keyFor(intention));
    _keys.settle(intention, keep: !result.ok && result.keepKey);
    return result;
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
