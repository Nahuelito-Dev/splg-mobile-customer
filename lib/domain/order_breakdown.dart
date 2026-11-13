import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/order_payments.dart';
import 'package:splg_customer/domain/reserved_orders.dart';

/// Lo que `GET /orders/:id` trae del pedido además de los datos que lee
/// `Order`: el desglose del total (renglones, recargo de zona y por medio de
/// pago) y el estado del cobro.
///
/// El recargo del medio de pago lo informa el back (`paymentSurchargeAmount` y
/// su porcentaje); con un back que no lo manda, es lo que sobra del total una
/// vez descontados los renglones y la zona.
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
    this.paymentSurchargeAmount,
    this.paymentSurchargePercentage,
    this.containerChargeAmount = 0,
    this.containersCharged = 0,
    this.reserved = false,
    this.depositAmount = 0,
    this.depositPaid = false,
    this.remainingBalance,
    this.paymentUrl,
    this.driverUserId,
    this.paymentMethodDetail,
  });

  final double total;

  /// Recargo por medio de pago que informa el back (`paymentSurchargeAmount`);
  /// null si el back no lo trae y hay que deducirlo del total.
  final double? paymentSurchargeAmount;

  /// Porcentaje con que se calculó; null en pedidos anteriores a que fuera
  /// configurable.
  final double? paymentSurchargePercentage;

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

  /// Cargo por los envases que el cliente compró con este pedido (ya está en
  /// el [total]); 0 en los pedidos que no los cobran o anteriores al cobro.
  final double containerChargeAmount;

  /// Envases cobrados, sumando `order_items[].containersCharged`.
  final int containersCharged;

  bool get chargesContainers => containerChargeAmount > 0;

  /// El back lo informa como `reserved`: reserva con seña que todavía no se
  /// despacha (CU-072).
  final bool reserved;

  /// Seña de la reserva (0 si no es reserva o no se dejó seña).
  final double depositAmount;
  final bool depositPaid;

  /// Saldo a cobrar al entregar, tal como lo informa el back; null si no vino.
  final double? remainingBalance;

  /// Enlace de Mercado Pago pendiente (en una reserva, el de la seña).
  final String? paymentUrl;

  /// Medio de pago real (`paymentMethodDetail`: `cash`, `transfer`,
  /// `mercadopago`); `payment_method` agrupa como `online` todo lo que no es
  /// efectivo.
  final String? paymentMethodDetail;

  bool get paysWithMercadoPago => paymentMethodDetail == 'mercadopago';

  /// `driver.userId`: sólo viene mientras el pedido está aceptado o en camino.
  final String? driverUserId;

  /// Es una reserva con seña: lo está siendo o lo fue y el sistema ya la activó.
  bool get isReservation => reserved || depositAmount > 0;

  /// La seña se cobra online y todavía no se pagó.
  bool get depositPending => isReservation && depositAmount > 0 && !depositPaid;

  bool get isExpress => deliveryMode == DeliveryMode.express;

  /// El express no encontró moto y siguió por el reparto común sin recargo.
  bool get expressDegraded => !isExpress && expressDegradedAt != null;

  /// Recargo express que hoy forma parte del [total].
  double get expressSurchargeInTotal => isExpress ? expressSurchargeAmount : 0;

  /// Recargo por el medio de pago, tal como lo informa el back; 0 si no lo informa.
  double get paymentSurcharge => paymentSurchargeAmount ?? 0;

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
      paymentSurchargeAmount: _num(raw['paymentSurchargeAmount']),
      paymentSurchargePercentage: _num(raw['paymentSurchargePercentage']),
      containerChargeAmount: _num(raw['containerChargeAmount']) ?? 0,
      containersCharged: _containersCharged(raw['order_items']),
      reserved: raw['status']?.toString().trim().toLowerCase() == 'reserved',
      depositAmount: _num(raw['depositAmount']) ?? 0,
      depositPaid: raw['depositPaid'] == true,
      remainingBalance: _num(raw['remainingBalance']),
      paymentUrl: _text(raw['payment_url'] ?? raw['paymentUrl']),
      paymentMethodDetail: _text(raw['paymentMethodDetail']),
      driverUserId: raw['driver'] is Map
          ? _text((raw['driver'] as Map)['userId'])
          : null,
    );
  }

  static String? _text(dynamic v) {
    final t = v?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  static int _containersCharged(dynamic items) {
    if (items is! List) return 0;
    var count = 0;
    for (final item in items) {
      if (item is Map) count += (_num(item['containersCharged']) ?? 0).toInt();
    }
    return count;
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
    !ReservedOrders.contains(order.id) &&
    breakdown?.reserved != true &&
    order.deliveryId == null &&
    order.paymentMethod != PaymentMethod.mercadoPago &&
    // La cuenta corriente la maneja el administrador; sin detalle no se sabe
    // a qué medio se pasaría.
    const {OrderPaymentKind.cash, OrderPaymentKind.transfer}
        .contains(OrderPayments.of(order)) &&
    (breakdown?.paymentStatus ?? 'pending') == 'pending' &&
    breakdown?.editable != false;

/// Si el cliente puede elegir otra dirección de entrega (CU-127): el pedido
/// está pendiente o aceptado y se sabe que no es express (se evaluó con la
/// dirección original); sin el desglose no se sabe, así que no se ofrece. Lo demás (pago en línea con otro recargo, ya salió) lo resuelve el
/// back con un 409.
bool canChangeOrderAddress(Order order, OrderBreakdown? breakdown) =>
    !ReservedOrders.contains(order.id) &&
    breakdown?.reserved != true &&
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
