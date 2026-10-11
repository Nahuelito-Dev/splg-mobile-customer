import 'package:splg_lib/network/api_error_text.dart';

/// Resultado de cancelar un pedido. El mensaje del back sólo se muestra si es
/// un 400/409 de negocio en castellano ("El pedido ya está en camino. Contacte
/// al soporte."); cualquier otro código usa un texto propio. "Reintentar" sólo
/// tiene sentido ante red caída, 429 o un 5xx ([retryable]).
class CancelResult {
  const CancelResult._(
    this.success,
    this.message, {
    this.rejected = false,
    this.retryable = false,
  });

  const CancelResult.ok() : this._(true, null);

  /// El back rechazó el pedido por una regla de negocio (400/409) con [message].
  const CancelResult.rejected(String message)
      : this._(false, message, rejected: true);

  /// Falla de red, 5xx o error inesperado; [message] es el texto propio para
  /// el usuario (null = el genérico de [failureDescription]).
  const CancelResult.failed({String? message, bool retryable = true})
      : this._(false, message, retryable: retryable);

  final bool success;
  final String? message;

  /// Rechazo de negocio: el estado del pedido pudo cambiar (p. ej. ya
  /// finalizado), conviene refrescar el historial.
  final bool rejected;

  /// Volver a intentar con la misma intención tiene sentido.
  final bool retryable;

  bool get isRejected => rejected;

  /// Texto para el diálogo de error.
  String get failureDescription =>
      message ??
      'No se pudo cancelar el pedido en este momento. Intentá nuevamente en unos segundos.';

  /// Interpreta la respuesta de `PATCH /orders/:id/cancel`.
  factory CancelResult.fromResponse(int? statusCode, dynamic data) {
    if (statusCode == 200 || statusCode == 204) return const CancelResult.ok();
    // La primera llamada sigue en curso: se espera y se reintenta con la
    // misma clave, sin mostrar el 409 técnico.
    if (ApiErrorText.isInProgress(statusCode, data)) {
      return const CancelResult.failed(
          message: ApiErrorText.inProgress, retryable: true);
    }
    final business = ApiErrorText.businessMessage(statusCode, data);
    if (business != null) return CancelResult.rejected(business);
    if (statusCode == null) return const CancelResult.failed();
    return CancelResult.failed(
      message: ApiErrorText.of(statusCode, data),
      retryable: ApiErrorText.isRetryable(statusCode),
    );
  }
}
