import 'package:flutter/foundation.dart';

/// Pedidos que el back informa como `reserved` (reserva con seña, CU-072).
///
/// `OrderStatus` de la lib todavía no tiene ese estado: el mapper los lee como
/// `pending` y deja acá el id para que las pantallas distingan la reserva de un
/// pedido que busca repartidor. Se actualiza en cada lectura del pedido, así que
/// cuando el sistema la activa (`reserved` → `pending`) deja de figurar.
class ReservedOrders {
  ReservedOrders._();

  static final Set<String> _ids = {};

  static bool contains(String orderId) => _ids.contains(orderId);

  static void mark(String orderId, {required bool reserved}) {
    if (orderId.isEmpty) return;
    if (reserved) {
      _ids.add(orderId);
    } else {
      _ids.remove(orderId);
    }
  }

  @visibleForTesting
  static void clear() => _ids.clear();
}
