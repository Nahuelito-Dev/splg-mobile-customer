import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/update_order_result.dart';

/// Cambia la dirección de entrega (CU-127) o indica quién recibe (CU-128) de un
/// pedido. La `Idempotency-Key` es de la intención (este pedido, con estos
/// datos): se genera una vez y se reusa en los reintentos —red caída, timeout,
/// 5xx, 429, 409 "en curso"—; otros datos son otra intención y llevan otra
/// clave, porque el back rechaza (422) la misma clave con un cuerpo distinto. La
/// clave se descarta cuando la intención se resuelve (aplicada, rechazo de
/// negocio o ese 422) o vence.
class ChangeOrderUseCase {
  ChangeOrderUseCase(this._orderRepository,
      {String Function()? newKey, DateTime Function()? now})
      : _keys = IdempotencyKeys(newKey: newKey, now: now);

  final OrderRepository _orderRepository;
  final IdempotencyKeys _keys;

  /// Descarta las intenciones en curso (al cerrar la sesión).
  void clear() => _keys.clear();

  Future<UpdateOrderResult> changeAddress(
    String orderId,
    String addressId,
    String token, {
    String? reason,
  }) async {
    final intention = 'address|$orderId|$addressId|${reason?.trim() ?? ''}';
    final result = await _orderRepository.changeOrderAddress(
        orderId, addressId, token, _keys.keyFor(intention),
        reason: reason);
    _settle(intention, result);
    return result;
  }

  Future<UpdateOrderResult> setReceiver(
    String orderId,
    OrderReceiver receiver,
    String token,
  ) async {
    final intention = 'receiver|$orderId|${receiver.name}|${receiver.document}|'
        '${receiver.relationship}';
    final result = await _orderRepository.setOrderReceiver(
        orderId, receiver.toJson(), token, _keys.keyFor(intention));
    _settle(intention, result);
    return result;
  }

  void _settle(String intention, UpdateOrderResult result) => _keys.settle(
      intention,
      keep: !result.success && result.retryable && !result.idempotencyConflict);
}
