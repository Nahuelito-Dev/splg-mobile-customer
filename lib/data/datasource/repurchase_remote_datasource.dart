import 'dart:developer';

import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Recompra anticipada del cliente (`/api/v2/customers/me/repurchase`).
class RepurchaseRemoteDatasource {
  final _api = ApiClient();

  static String _url(String path) =>
      '${AppConfig.apiV2Url}customers/me/repurchase$path';

  Future<ApiResult<dynamic>> forecast(String token) =>
      _run('forecast', () => _api.get(_url(''), token));

  Future<ApiResult<dynamic>> notice(String token) =>
      _run('notice', () => _api.get(_url('/notice'), token));

  Future<ApiResult<dynamic>> updateNotice(
          Map<String, dynamic> body, String token) =>
      _run('updateNotice', () => _api.patch(_url('/notice'), body, token));

  Future<ApiResult<dynamic>> invitations(String token) =>
      _run('invitations', () => _api.get(_url('/invitations'), token));

  Future<ApiResult<dynamic>> accept(
          String id, Map<String, dynamic> body, String token, String key) =>
      _run(
          'accept',
          () => _api.post(_url('/invitations/$id/accept'), body, token,
              {'Idempotency-Key': key}));

  Future<ApiResult<dynamic>> dismiss(String id, String token) =>
      _run('dismiss',
          () => _api.post(_url('/invitations/$id/dismiss'), const {}, token));

  Future<ApiResult<dynamic>> _run(
      String what, Future<dynamic> Function() call) async {
    try {
      final response = await call();
      final status = response.statusCode as int?;
      return status != null && status >= 200 && status < 300
          ? ApiResult.ok(response.data)
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      log('e in repurchase.$what: ${e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }
}
