import 'package:splg_lib/domain/order.dart';

/// Resultado de crear un pedido.
///
/// Además de indicar éxito y devolver el [Order] creado, propaga el
/// `paymentUrl` (init_point de Checkout Pro de MercadoPago) que el backend
/// incluye en la respuesta cuando el pedido se crea con
/// `paymentMethod: mercadopago`. Para `cash`/`transfer` viene null.
class CreateOrderResult {
  const CreateOrderResult({
    required this.success,
    this.order,
    this.paymentUrl,
    this.message,
    this.retryable = true,
    this.idempotencyConflict = false,
    this.expressUnavailableReason,
    this.priceChanged = false,
  });

  final bool success;

  /// Texto para el usuario cuando falló: el mensaje del back si es una regla
  /// de negocio (fuera de zona, sin stock), o uno propio por tipo de error.
  final String? message;

  /// Volver a intentar con la misma intención tiene sentido (red caída, 429,
  /// 5xx). Un rechazo de negocio (400/409) no: hay que cambiar el pedido.
  final bool retryable;

  /// 422: la misma `Idempotency-Key` ya se usó con otro cuerpo, es decir que el
  /// primer envío llegó y el pedido probablemente existe.
  final bool idempotencyConflict;

  /// 409 `EXPRESS_NOT_AVAILABLE`: el motivo (`out_of_hours`, ...) por el que el
  /// express dejó de estar disponible entre que se eligió y se creó el pedido.
  /// No se creó nada: el cliente puede elegir el reparto común.
  final String? expressUnavailableReason;

  /// 409 `PRICE_CHANGED`: el total ya no es el que se cotizó (cambió una
  /// promoción, el recargo, la zona…). No se creó nada: hay que volver a
  /// cotizar y confirmar de nuevo.
  final bool priceChanged;

  final Order? order;
  final String? paymentUrl;
}
