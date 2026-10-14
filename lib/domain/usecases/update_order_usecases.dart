import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/update_order_result.dart';

/// Edita un pedido. La `Idempotency-Key` es de la sesión de edición de ese
/// pedido, no del cuerpo: se genera una vez y se reusa en los reintentos —red
/// caída, timeout, 5xx, 429, 409 "en curso"— aunque el cliente haya cambiado
/// algo mientras tanto. Si la primera llamada sí llegó y se cambia la clave, el
/// back aplica la edición dos veces; si el cuerpo cambió con la misma clave,
/// responde 422 y se avisa en vez de mandar otra. La clave se descarta cuando
/// la edición se resuelve (aplicada, rechazo de negocio o ese 422) o vence.
class UpdateOrderUseCase {
  UpdateOrderUseCase(this._orderRepository,
      {String Function()? newKey, DateTime Function()? now})
      : _keys = IdempotencyKeys(newKey: newKey, now: now);

  final OrderRepository _orderRepository;
  final IdempotencyKeys _keys;

  /// Descarta las ediciones en curso (al cerrar la sesión).
  void clear() => _keys.clear();

  Future<UpdateOrderResult> call(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
  ) async {
    final intention = 'edit|$orderId';
    final result = await _orderRepository.updateOrder(
        orderId, orderData, token, _keys.keyFor(intention));
    _keys.settle(intention,
        keep:
            !result.success && result.retryable && !result.idempotencyConflict);
    return result;
  }
}
