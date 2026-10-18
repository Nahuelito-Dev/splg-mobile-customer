import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_receiver.dart';

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
    this.deliveryMode = DeliveryMode.standard,
    this.expressSurchargeAmount = 0,
    this.expressDegradedAt,
    this.receiver,
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

  /// Modalidad vigente: un express que ninguna moto aceptó pasa a `standard`.
  final DeliveryMode deliveryMode;

  /// Recargo express que se cobró al pedir. Se conserva aunque el pedido pase
  /// al reparto común; en ese caso el [total] ya no lo incluye.
  final double expressSurchargeAmount;

  /// Cuándo el express pasó al reparto común; null si no pasó.
  final DateTime? expressDegradedAt;

  /// Quién recibe, si el cliente lo indicó.
  final OrderReceiver? receiver;

  bool get isExpress => deliveryMode == DeliveryMode.express;

  /// El express no encontró moto y siguió por el reparto común sin recargo.
  bool get expressDegraded => !isExpress && expressDegradedAt != null;

  /// Recargo express que hoy forma parte del [total].
  double get expressSurchargeInTotal => isExpress ? expressSurchargeAmount : 0;

  /// Recargo por el medio de pago; 0 si no hay con qué calcularlo.
  double get paymentSurcharge {
    final items = itemsSubtotal;
    if (items == null) return 0;
    final rest =
        ((total - items - zoneSurcharge - expressSurchargeInTotal) * 100)
                .round() /
            100;
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
      deliveryMode: DeliveryMode.fromWire(raw['deliveryMode']),
      expressSurchargeAmount: _num(raw['expressSurchargeAmount']) ?? 0,
      expressDegradedAt: raw['expressDegradedAt'] == null
          ? null
          : DateTime.tryParse(raw['expressDegradedAt'].toString()),
      receiver: OrderReceiver.fromJson(raw['receiver']),
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

/// Si el cliente puede elegir otra dirección de entrega (CU-127): el pedido
/// está pendiente o aceptado y se sabe que no es express (se evaluó con la
/// dirección original); sin el desglose no se sabe, así que no se ofrece. Lo demás (pago en línea con otro recargo, ya salió) lo resuelve el
/// back con un 409.
bool canChangeOrderAddress(Order order, OrderBreakdown? breakdown) =>
    (order.status == OrderStatus.pending ||
        order.status == OrderStatus.accepted) &&
    breakdown != null &&
    !breakdown.isExpress;

/// Si el cliente puede indicar quién recibe (CU-128): mientras el pedido no
/// esté entregado ni cancelado.
bool canSetOrderReceiver(Order order) =>
    order.status != OrderStatus.delivered &&
    order.status != OrderStatus.cancelled;

/// Un pedido con su desglose.
class OrderDetail {
  const OrderDetail(this.order, this.breakdown);

  final Order order;
  final OrderBreakdown? breakdown;
}
