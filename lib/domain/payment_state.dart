/// El estado del pago de Mercado Pago de un pedido tal como lo informa el back
/// (`GET /api/v2/orders/:id/payment`).
///
/// El texto ([label]) lo arma el back: la app lo muestra tal cual y no decide
/// el estado ni reinterpreta el motivo. [canRetry] y [paymentUrl] también
/// vienen del back: el botón de pagar sólo existe cuando el back lo permite.
class PaymentState {
  const PaymentState({
    this.status,
    this.detail,
    this.label,
    this.canRetry = false,
    this.paymentUrl,
  });

  /// Uno de los nueve estados de pago de Mercado Pago (`rejected`, `approved`,
  /// `in_process`...); null si el pedido no tiene pagos de Mercado Pago.
  final String? status;

  /// Motivo del estado (`status_detail`), tal cual.
  final String? detail;

  /// El texto en castellano, armado por el back.
  final String? label;

  /// El pedido sigue vivo y sin pagar, el pago no está en curso y el enlace no
  /// venció: se puede pagar (o reintentar) con [paymentUrl].
  final bool canRetry;

  /// Enlace de Checkout Pro para pagar o reintentar; null si no se puede.
  final String? paymentUrl;

  /// Hay un pago de Mercado Pago del que informar.
  bool get hasPayment => status != null && (label?.isNotEmpty ?? false);

  /// El comprador ya intentó pagar y no se pudo: el botón dice «Reintentar».
  bool get wasRejected => status == 'rejected' || status == 'cancelled';

  /// Se puede ofrecer el botón: el back lo permite y hay enlace.
  bool get canPay => canRetry && (paymentUrl?.isNotEmpty ?? false);

  static PaymentState? fromJson(Object? json) {
    if (json is! Map) return null;
    String? text(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    return PaymentState(
      status: text('paymentStatus'),
      detail: text('paymentStatusDetail'),
      label: text('paymentStatusLabel'),
      canRetry: json['canRetry'] == true,
      paymentUrl: text('paymentUrl'),
    );
  }
}
