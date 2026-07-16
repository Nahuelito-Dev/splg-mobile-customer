/// Resultado de haber pasado por el WebView de Checkout Pro de MercadoPago.
///
/// No es una confirmación real del pago (esa la hace el webhook del backend
/// contra MercadoPago); es sólo la señal de a qué `back_url` redirigió MP
/// (o si el cliente cerró el WebView antes de llegar a alguna).
enum PaymentOutcome {
  /// MP redirigió a `MP_SUCCESS_URL`.
  success,

  /// MP redirigió a `MP_FAILURE_URL`.
  failure,

  /// MP redirigió a `MP_PENDING_URL` (p.ej. pago en efectivo/transferencia
  /// dentro de Checkout Pro, que demora en acreditarse).
  pending,

  /// El cliente cerró el WebView manualmente sin llegar a ninguna back_url.
  cancelled,
}
