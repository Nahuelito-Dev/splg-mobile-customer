import 'package:uuid/uuid.dart';

import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';

/// Cancela un pedido. La `Idempotency-Key` se genera una sola vez por intención
/// de cancelar (un pedido) y se reusa en los reintentos —red caída, 5xx, 429—:
/// si la primera llamada sí llegó al back, el reintento no la procesa de nuevo.
/// La clave se descarta cuando la intención se resuelve (éxito o rechazo).
class CancelOrderUseCase {
  CancelOrderUseCase(this._orderRepository, {String Function()? newKey})
      : _newKey = newKey ?? (() => const Uuid().v4());

  final OrderRepository _orderRepository;
  final String Function() _newKey;
  final Map<String, String> _keys = {};

  /// Descarta las claves de intenciones en curso (al cerrar la sesión).
  void clear() => _keys.clear();

  Future<CancelResult> call(String orderId, String token,
      {String? reason}) async {
    final key = _keys.putIfAbsent(orderId, _newKey);
    final result = await _orderRepository.cancelOrder(orderId, token, key,
        reason: reason);
    if (result.success || !result.retryable) _keys.remove(orderId);
    return result;
  }
}
