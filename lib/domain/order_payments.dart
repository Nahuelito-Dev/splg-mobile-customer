import 'package:flutter/foundation.dart';
import 'package:splg_lib/domain/order.dart';

/// Medio de pago real de un pedido. El back agrupa en `payment_method` (`cash`,
/// `online`, `account`) y da el medio en `paymentMethodDetail`.
enum OrderPaymentKind {
  cash,
  transfer,
  mercadoPago,

  /// Cuenta corriente: la carga el administrador desde el panel.
  account,

  /// En línea sin detalle: no se sabe si es transferencia o Mercado Pago.
  online,
}

/// Medio de pago de cada pedido leído del back.
///
/// `PaymentMethod` de la lib no tiene la cuenta corriente ni un pago en línea
/// sin detalle: el mapper los lee con un valor que la lib sí tiene y deja acá el
/// medio real, como hace `ReservedOrders` con la reserva. Se actualiza en cada
/// lectura del pedido.
class OrderPayments {
  OrderPayments._();

  static final Map<String, OrderPaymentKind> _kinds = {};

  /// Anota el medio leído y devuelve el que queda anotado.
  static OrderPaymentKind mark(String orderId, OrderPaymentKind kind) {
    if (orderId.isEmpty) return kind;
    // Una lectura sin detalle (`online`) no pisa el medio ya conocido: el medio
    // de un pedido no cambia de Mercado Pago o transferencia a «en línea».
    final known = _kinds[orderId];
    if (kind == OrderPaymentKind.online &&
        (known == OrderPaymentKind.transfer ||
            known == OrderPaymentKind.mercadoPago)) {
      return known!;
    }
    return _kinds[orderId] = kind;
  }

  /// El medio anotado por el mapper; un pedido armado en la app (sin pasar por
  /// el back) usa el de su `PaymentMethod`.
  static OrderPaymentKind of(Order order) =>
      _kinds[order.id] ??
      switch (order.paymentMethod) {
        PaymentMethod.cash => OrderPaymentKind.cash,
        PaymentMethod.online => OrderPaymentKind.transfer,
        PaymentMethod.mercadoPago => OrderPaymentKind.mercadoPago,
      };

  /// El medio según `payment_method` y `paymentMethodDetail` del back.
  static OrderPaymentKind fromApi(String? method, String? detail) =>
      switch (detail ?? method) {
        'transfer' => OrderPaymentKind.transfer,
        'mercadopago' => OrderPaymentKind.mercadoPago,
        'account' => OrderPaymentKind.account,
        'online' => OrderPaymentKind.online,
        _ => OrderPaymentKind.cash,
      };

  @visibleForTesting
  static void clear() => _kinds.clear();
}
