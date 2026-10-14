import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:splg_lib/network/api_error_text.dart';

import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';

class AddressRemoteDataSource {
  final _apiClient = ApiClient();

  Future<bool> createAddress(
    Map<String, dynamic> addressData,
    String token,
    String userId,
  ) async {
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
  /// Ante cualquier error lanza: una falla no es "no tiene direcciones".
  Future<List<Map<String, dynamic>>> fetchByUser(
    String userId,
    String token,
  ) async {
    final response = await _apiClient.get('user-address/user/$userId', token);
    final data = response.data;
    if (data is! List) throw const FormatException('Direcciones ilegibles');
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Alta de una dirección ya geocodificada (`POST /user-address`). El body
  /// lleva los nombres del DTO del back (camelCase) y `latitude`/`longitude`
  /// obligatorios. Idempotente por `Idempotency-Key` ([idempotencyKey]): el
  /// reintento de una misma dirección lleva la misma clave.
  Future<ApiResult<void>> create(
    Map<String, dynamic> body,
    String token,
    String idempotencyKey,
  ) =>
      _send(() => _apiClient.post(
            'user-address',
            body,
            token,
            {'Idempotency-Key': idempotencyKey},
          ));

  /// Actualiza una dirección (`PATCH /user-address/:id`).
  Future<ApiResult<void>> update(
    String addressId,
    Map<String, dynamic> body,
    String token,
  ) =>
      _send(() => _apiClient.patch('user-address/$addressId', body, token));

  /// Marca una dirección como predeterminada
  /// (`PATCH /user-address/:id/set-default`).
  Future<ApiResult<void>> setDefault(String addressId, String token) => _send(
        () =>
            _apiClient.patch('user-address/$addressId/set-default', {}, token),
      );

  /// Elimina una dirección (`DELETE /user-address/:id`).
  Future<ApiResult<void>> delete(String addressId, String token) =>
      _send(() => _apiClient.delete('user-address/$addressId', token));

  Future<ApiResult<void>> _send(Future<Response> Function() call) async {
    try {
      final r = await call();
      final code = r.statusCode ?? 0;
      return code >= 200 && code < 300
          ? const ApiResult.ok()
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }
}
