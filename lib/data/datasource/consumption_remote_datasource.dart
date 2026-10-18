import 'dart:developer';

import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Consumo promedio declarado del cliente (`/customers/me/consumption`).
class ConsumptionRemoteDatasource {
  final _apiClient = ApiClient();

  Future<ApiResult<dynamic>> fetch(String token) async {
    try {
      final response = await _apiClient.get('customers/me/consumption', token);
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in consumption.fetch: ${e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }

  Future<ApiResult<dynamic>> update(
      Map<String, dynamic> body, String token) async {
    try {
      final response =
          await _apiClient.patch('customers/me/consumption', body, token);
      final status = response.statusCode;
      return status == 200 || status == 204
          ? ApiResult.ok(response.data)
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      log('e in consumption.update: ${e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }
}
