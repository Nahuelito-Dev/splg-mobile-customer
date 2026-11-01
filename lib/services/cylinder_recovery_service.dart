import 'package:splg_lib/network/api_error_text.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/cylinder_recovery_remote_datasource.dart';
import 'package:splg_customer/domain/cylinder_recovery.dart';
import 'package:splg_customer/services/customer_service.dart';

/// Recupero de envases (M5): los envases que el cliente todavía no devolvió y
/// la oferta de retirarlos en su próxima entrega. Con el módulo apagado la
/// lista viene vacía.
class CylinderRecoveryService {
  /// [datasource] y [tokenReader] sólo se inyectan en los tests.
  CylinderRecoveryService({
    CylinderRecoveryRemoteDatasource? datasource,
    Future<String?> Function()? tokenReader,
  })  : _remote = datasource ?? CylinderRecoveryRemoteDatasource(),
        _tokenReader = tokenReader;

  final CylinderRecoveryRemoteDatasource _remote;
  final Future<String?> Function()? _tokenReader;

  Future<String?> _token() {
    final read = _tokenReader;
    return read != null ? read() : locator<CustomerService>().token;
  }

  /// `GET /cylinder-recovery/mine`: mis casos abiertos o escalados.
  Future<ApiResult<List<RecoveryCase>>> mine() async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final r = await _remote.mine(token);
    if (!r.ok) return ApiResult.fail(r.message!, status: r.status);
    final data = r.data;
    if (data is! List) return const ApiResult.fail(ApiErrorText.generic);
    return ApiResult.ok([
      for (final c in data)
        if (RecoveryCase.fromJson(c) case final rc?) rc
    ]);
  }

  /// «Lo devuelvo en mi próxima entrega». 409: la oferta venció o ya no aplica.
  Future<ApiResult<void>> acceptPickup(String caseId) =>
      _answer(caseId, _remote.acceptPickup);

  /// Rechaza la oferta: el caso sigue en su escalón.
  Future<ApiResult<void>> declinePickup(String caseId) =>
      _answer(caseId, _remote.declinePickup);

  Future<ApiResult<void>> _answer(
    String caseId,
    Future<ApiResult<dynamic>> Function(String caseId, String token) call,
  ) async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final r = await call(caseId, token);
    return r.ok
        ? const ApiResult.ok()
        : ApiResult.fail(r.message!, status: r.status);
  }
}
