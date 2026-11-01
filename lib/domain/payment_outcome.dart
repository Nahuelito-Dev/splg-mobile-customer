import 'package:splg_customer/core/config/app_config.dart';

/// Cómo volvió el cliente de Checkout Pro de MercadoPago.
///
/// No es una confirmación real del pago (esa la hace el webhook del backend
/// contra MercadoPago); es sólo la señal de a qué `back_url` redirigió MP.
enum PaymentOutcome {
  /// MP redirigió a `splg://pago/exito`.
  success,

  /// MP redirigió a `splg://pago/error`.
  failure,

  /// MP redirigió a `splg://pago/pendiente` (p.ej. pago que demora en
  /// acreditarse).
  pending,
}

/// La vuelta de MP a la app: el resultado y, si el link lo trae, el pedido
/// (`external_reference` = id del pedido).
class PaymentReturn {
  const PaymentReturn(this.outcome, {this.orderId, this.paymentId});

  final PaymentOutcome outcome;
  final String? orderId;
  final String? paymentId;

  /// Interpreta un deep link entrante; null si no es de pago.
  static PaymentReturn? fromUri(Uri uri) {
    if (uri.scheme != AppConfig.paymentLinkScheme ||
        uri.host != AppConfig.paymentLinkHost) {
      return null;
    }
    final outcome = switch (uri.pathSegments.firstOrNull) {
      'exito' => PaymentOutcome.success,
      'pendiente' => PaymentOutcome.pending,
      'error' => PaymentOutcome.failure,
      _ => null,
    };
    if (outcome == null) return null;
    String? param(String key) {
      final v = uri.queryParameters[key];
      return v == null || v.isEmpty || v == 'null' ? null : v;
    }

    return PaymentReturn(
      outcome,
      orderId: param('external_reference'),
      paymentId: param('payment_id') ?? param('collection_id'),
    );
  }
}
