import 'package:splg_lib/domain/order.dart';

/// Lo que `GET /orders/:id` trae del pedido además de los datos que lee
/// `Order`: el desglose del total (renglones, recargo de zona y por medio de
/// pago) y el estado del cobro.
///
/// El back no manda el recargo del medio de pago como campo: es lo que sobra
/// del total una vez descontados los renglones y la zona.
class OrderBreakdown {
  const OrderBreakdown({
    required this.total,
    this.itemsSubtotal,
    this.zoneSurcharge = 0,
    this.zoneName,
    this.paymentStatus,
    this.editable,
    this.scheduledDate,
  });

  final double total;

  /// Suma de los renglones con la promoción por volumen aplicada; null si el
  /// back no la informó.
  final double? itemsSubtotal;
  final double zoneSurcharge;
  final String? zoneName;

  /// `pending`, `paid`, `failed`, `unpaid`, `written_off`.
  final String? paymentStatus;

  /// La regla del pedido según el back (pendiente, sin chofer y sin pago online
  /// en curso o cobrado); null si no la informó.
  final bool? editable;

  /// Fecha agendada de la entrega (`YYYY-MM-DD`), si hay.
  final String? scheduledDate;

  /// Recargo por el medio de pago; 0 si no hay con qué calcularlo.
  double get paymentSurcharge {
    final items = itemsSubtotal;
    if (items == null) return 0;
    final rest = ((total - items - zoneSurcharge) * 100).round() / 100;
    return rest > 0 ? rest : 0;
  }

  /// Lee el cuerpo de `GET /orders/:id`; null si no es un objeto con total.
  static OrderBreakdown? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final total = _num(raw['total_amount'] ?? raw['totalAmount']);
    if (total == null) return null;
    final zone = raw['zone_surcharge'];
    return OrderBreakdown(
      total: total,
      itemsSubtotal: _num(raw['subtotal_items']),
      zoneSurcharge: zone is Map ? _num(zone['amount']) ?? 0 : 0,
      zoneName: zone is Map ? zone['name']?.toString() : null,
      paymentStatus: raw['paymentStatus']?.toString(),
      editable: raw['editable'] is bool ? raw['editable'] as bool : null,
      scheduledDate: raw['scheduledDate']?.toString(),
    );
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Si el cliente puede modificar el pedido: pendiente, sin repartidor, que no
/// sea de Mercado Pago y con el cobro sin tocar. Es la regla del back
/// (`PATCH /orders/:id`); si éste informó `editable`, también tiene que dar sí.
bool canEditOrder(Order order, OrderBreakdown? breakdown) =>
    order.status == OrderStatus.pending &&
    order.deliveryId == null &&
    order.paymentMethod != PaymentMethod.mercadoPago &&
    (breakdown?.paymentStatus ?? 'pending') == 'pending' &&
    breakdown?.editable != false;

/// Un pedido con su desglose.
class OrderDetail {
  const OrderDetail(this.order, this.breakdown);

  final Order order;
  final OrderBreakdown? breakdown;
}
