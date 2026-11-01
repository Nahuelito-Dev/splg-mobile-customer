import 'dart:developer';

import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Recupero de envases del cliente (`/api/v2/cylinder-recovery/mine`).
class CylinderRecoveryRemoteDatasource {
  final _api = ApiClient();

  static String _url(String path) =>
      '${AppConfig.apiV2Url}cylinder-recovery/mine$path';

  Future<ApiResult<dynamic>> mine(String token) =>
      _run('mine', () => _api.get(_url(''), token));

  Future<ApiResult<dynamic>> acceptPickup(String caseId, String token) =>
      _run('accept',
          () => _api.post(_url('/$caseId/pickup/accept'), const {}, token));

  Future<ApiResult<dynamic>> declinePickup(String caseId, String token) =>
      _run('decline',
          () => _api.post(_url('/$caseId/pickup/decline'), const {}, token));

  Future<ApiResult<dynamic>> _run(
      String what, Future<dynamic> Function() call) async {
    try {
      final response = await call();
      final status = response.statusCode as int?;
      return status != null && status >= 200 && status < 300
          ? ApiResult.ok(response.data)
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      log('e in cylinderRecovery.$what: ${e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }
}
