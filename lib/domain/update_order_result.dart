import 'package:splg_lib/domain/order.dart';

/// Resultado de editar un pedido (`PATCH /orders/:id`).
class UpdateOrderResult {
  const UpdateOrderResult({
    required this.success,
    this.order,
    this.message,
    this.retryable = false,
    this.rejected = false,
    this.idempotencyConflict = false,
  });

  final bool success;

  /// El pedido tal como quedó (con el total que calculó el back).
  final Order? order;

  /// Texto para el usuario cuando falló.
  final String? message;

  /// Volver a mandar lo mismo tiene sentido (red caída, 429, 5xx, 409 "en
  /// curso").
  final bool retryable;

  /// El back rechazó por una regla de negocio (400/409): el pedido pudo cambiar
  /// de estado (lo tomó un repartidor), conviene releerlo.
  final bool rejected;

  /// 422: la misma `Idempotency-Key` ya se usó con otro cuerpo, es decir que el
  /// primer envío llegó y el pedido probablemente quedó editado.
  final bool idempotencyConflict;
}

/// Texto cuando el primer envío de la edición pudo haber llegado.
const String kOrderMaybeEditedText =
    'Tu cambio anterior ya se guardó; revisá el pedido y volvé a editar si '
    'hace falta.';
