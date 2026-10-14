import 'package:dio/dio.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/core/network/idempotency.dart';

/// Resultado de una llamada a la API: el dato si salió bien, o el texto para
/// el usuario (`ApiErrorText`) si no.
class ApiResult<T> {
  const ApiResult.ok([this.data])
      : ok = true,
        message = null,
        status = null,
        keepKey = false;

  const ApiResult.fail(String this.message, {this.status, this.keepKey = false})
      : ok = false,
        data = null;

  /// Traduce un error de Dio (o cualquier excepción) al texto de la app.
  factory ApiResult.fromError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final data = error.response?.data;
      return ApiResult.fail(
        isIdempotencyConflict(code, data)
            ? kIdempotencyConflictText
            : ApiErrorText.of(code, data),
        status: code,
        keepKey: keepIdempotencyKey(code, data),
      );
    }
    return const ApiResult.fail(ApiErrorText.generic);
  }

  final bool ok;
  final T? data;
  final String? message;
  final int? status;

  /// La llamada lleva `Idempotency-Key` y el próximo intento de la misma
  /// intención tiene que reusarla (no hubo respuesta, 5xx, 429, 409 "en curso"
  /// o 422 de clave ya usada).
  final bool keepKey;
}

/// Falla de lectura con el texto ya listo para mostrar.
class LoadFailure implements Exception {
  const LoadFailure(this.message, {this.retryable = true});

  final String message;

  /// Volver a pedirlo puede dar otro resultado (false: el recurso no existe).
  final bool retryable;
}
