import 'package:dio/dio.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Resultado de una llamada a la API: el dato si salió bien, o el texto para
/// el usuario (`ApiErrorText`) si no.
class ApiResult<T> {
  const ApiResult.ok([this.data])
      : ok = true,
        message = null,
        status = null;

  const ApiResult.fail(String this.message, {this.status})
      : ok = false,
        data = null;

  /// Traduce un error de Dio (o cualquier excepción) al texto de la app.
  factory ApiResult.fromError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      return ApiResult.fail(
        ApiErrorText.of(code, error.response?.data),
        status: code,
      );
    }
    return const ApiResult.fail(ApiErrorText.generic);
  }

  final bool ok;
  final T? data;
  final String? message;
  final int? status;
}

/// Falla de lectura con el texto ya listo para mostrar.
class LoadFailure implements Exception {
  const LoadFailure(this.message);

  final String message;
}
