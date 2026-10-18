import 'package:splg_lib/network/api_error_text.dart';

import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/consumption_remote_datasource.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/app/app.locator.dart';

/// Resultado de guardar el consumo: ok, fuera de rango (pide confirmar) o error.
enum ConsumptionSaveStatus { saved, needsConfirmation, failed }

class ConsumptionSaveOutcome {
  const ConsumptionSaveOutcome(this.status, {this.consumption, this.message});

  final ConsumptionSaveStatus status;
  final Consumption? consumption;
  final String? message;
}

/// Consumo promedio declarado (CU-144): lectura y corrección desde el perfil.
class ConsumptionService {
  /// [datasource] y [tokenReader] sólo se inyectan en los tests.
  ConsumptionService({
    ConsumptionRemoteDatasource? datasource,
    Future<String?> Function()? tokenReader,
  })  : _remote = datasource ?? ConsumptionRemoteDatasource(),
        _tokenReader = tokenReader;

  final ConsumptionRemoteDatasource _remote;
  final Future<String?> Function()? _tokenReader;

  Future<String?> _token() {
    final read = _tokenReader;
    return read != null ? read() : locator<CustomerService>().token;
  }

  /// `GET /customers/me/consumption`: lo declarado (todo vacío si nunca declaró).
  Future<ApiResult<Consumption>> fetch() async {
    final token = await _token();
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final r = await _remote.fetch(token);
    if (!r.ok) return ApiResult.fail(r.message!, status: r.status);
    final c = Consumption.fromJson(r.data);
    return c == null
        ? const ApiResult.fail(ApiErrorText.generic)
        : ApiResult.ok(c);
  }

  /// `PATCH /customers/me/consumption`. Fuera de rango el back responde 400 y
  /// no guarda: vuelve [ConsumptionSaveStatus.needsConfirmation] y quien llama
  /// reenvía con `confirmed()` si el cliente acepta.
  Future<ConsumptionSaveOutcome> save(
      ConsumptionDeclaration declaration) async {
    final token = await _token();
    if (token == null) {
      return const ConsumptionSaveOutcome(ConsumptionSaveStatus.failed,
          message: ApiErrorText.sessionExpired);
    }
    final r = await _remote.update(declaration.toJson(), token);
    if (r.ok) {
      final c = Consumption.fromJson(r.data);
      return c == null
          ? const ConsumptionSaveOutcome(ConsumptionSaveStatus.failed,
              message: ApiErrorText.generic)
          : ConsumptionSaveOutcome(ConsumptionSaveStatus.saved, consumption: c);
    }
    if (!declaration.confirmOutOfRange &&
        isConsumptionOutOfRange(r.status, r.body)) {
      return const ConsumptionSaveOutcome(
          ConsumptionSaveStatus.needsConfirmation);
    }
    return ConsumptionSaveOutcome(ConsumptionSaveStatus.failed,
        message: r.message);
  }
}
