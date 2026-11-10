import 'dart:developer';

import 'package:dio/dio.dart';

import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';

class CoverageRemoteDatasource {
  final _apiClient = ApiClient();

  /// `GET /coverage-zones/check?lat=&lng=` (CU-058): si el punto cae dentro de
  /// la cobertura de la distribuidora. Un error vuelve como `ApiResult.fail`.
  Future<ApiResult<dynamic>> check(
    double lat,
    double lng,
    String token,
  ) async {
    try {
      final response = await _apiClient.get(
        'coverage-zones/check?lat=$lat&lng=$lng',
        token,
      );
      return ApiResult.ok(response.data);
    } catch (e) {
      log('e in coverage check: ${e is DioException ? e.response?.statusCode : e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }
}
