import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';

/// Crea un pedido. La `Idempotency-Key` es de la sesión de checkout, no del
/// cuerpo: se genera una vez y se reusa en los reintentos —red caída, timeout,
/// 5xx, 429, 409 "en curso"— aunque el cliente haya cambiado algo del pedido
/// (una nota, el medio de pago) mientras tanto. Si la primera llamada sí llegó
/// y se cambia la clave, el back crea un segundo pedido. Si el cuerpo cambió, el
/// back responde 422 (misma clave, otros datos): el primer pedido probablemente
/// se creó, y se avisa en vez de mandar uno nuevo. La clave se descarta cuando
/// la intención se resuelve (creado, rechazo de negocio o ese 422) o vence.
class CreateOrderUseCase {
  CreateOrderUseCase(this._orderRepository,
      {String Function()? newKey, DateTime Function()? now})
      : _keys = IdempotencyKeys(newKey: newKey, now: now);

  static const _intention = 'checkout';

  final OrderRepository _orderRepository;
  final IdempotencyKeys _keys;

  /// Descarta la intención en curso (al cerrar la sesión).
  void clear() => _keys.clear();

  Future<CreateOrderResult> call(
    Map<String, dynamic> orderData,
    String token,
  ) async {
    final result = await _orderRepository.createOrder(
        orderData, token, _keys.keyFor(_intention));
    // El 422 ya se explicó: el próximo intento es una decisión nueva.
    final keep =
        !result.success && result.retryable && !result.idempotencyConflict;
    _keys.settle(_intention, keep: keep);
    return result;
  }
}
