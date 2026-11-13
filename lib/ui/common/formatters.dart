import 'package:intl/intl.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:splg_customer/domain/order_payments.dart';
import 'package:splg_customer/domain/reserved_orders.dart';

/// Importes en pesos: sin decimales si el monto es entero, con centavos si no
/// (un total con recargo puede dar 47701,5: mostrarlo redondeado no coincide
/// con lo que se cobra).
class Money {
  const Money();

  static final _whole = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
    customPattern: '¤#,##0',
  );
  static final _cents = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  String format(num value) => (value % 1 == 0 ? _whole : _cents).format(value);
}

const money = Money();

String dateTimeLabel(DateTime d) =>
    DateFormat('dd/MM/yyyy · HH:mm', 'es_AR').format(d.toLocal());

String dateLabel(DateTime d) =>
    DateFormat('dd/MM/yyyy', 'es_AR').format(d.toLocal());

String statusLabel(OrderStatus s) => switch (s) {
      OrderStatus.pending => 'PENDIENTE',
      OrderStatus.accepted => 'ASIGNADO',
      OrderStatus.outForDelivery => 'EN CAMINO',
      OrderStatus.delivered => 'ENTREGADO',
      OrderStatus.cancelled => 'CANCELADO',
    };

/// Como [statusLabel] pero distingue la reserva con seña, que el back informa
/// como `reserved` y la lib todavía lee como pendiente.
String orderStatusLabel(Order o) =>
    ReservedOrders.contains(o.id) ? 'RESERVADO' : statusLabel(o.status);

SplgTone orderStatusTone(Order o) =>
    ReservedOrders.contains(o.id) ? SplgTone.info : statusTone(o.status);

SplgTone statusTone(OrderStatus s) => switch (s) {
      OrderStatus.pending => SplgTone.warn,
      OrderStatus.accepted => SplgTone.info,
      OrderStatus.outForDelivery => SplgTone.info,
      OrderStatus.delivered => SplgTone.success,
      OrderStatus.cancelled => SplgTone.danger,
    };

bool isActive(OrderStatus s) =>
    s == OrderStatus.pending ||
    s == OrderStatus.accepted ||
    s == OrderStatus.outForDelivery;

String paymentLabel(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Efectivo',
      PaymentMethod.online => 'Transferencia',
      PaymentMethod.mercadoPago => 'Mercado Pago',
    };

/// El medio de pago de un pedido leído del back, con la cuenta corriente y el
/// pago en línea sin detalle (que no se afirma como transferencia).
String orderPaymentLabel(Order order) => switch (OrderPayments.of(order)) {
      OrderPaymentKind.cash => 'Efectivo',
      OrderPaymentKind.transfer => 'Transferencia',
      OrderPaymentKind.mercadoPago => 'Mercado Pago',
      OrderPaymentKind.account => 'Cuenta corriente',
      OrderPaymentKind.online => 'Pago en línea',
    };

/// El medio de un pedido como lo nombra [paymentSurchargeLabel].
String? orderSurchargeMethod(Order order) => switch (OrderPayments.of(order)) {
      OrderPaymentKind.cash => 'cash',
      OrderPaymentKind.transfer => 'transfer',
      OrderPaymentKind.mercadoPago => 'mercadopago',
      OrderPaymentKind.account || OrderPaymentKind.online => null,
    };

/// Porcentaje para mostrar: "10", "7,5", "12,34" (hasta 2 decimales, coma).
String percentLabel(double value) {
  final text = value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return text.replaceFirst(RegExp(r'\.$'), '').replaceFirst('.', ',');
}

/// "Recargo por transferencia (10 %)": el medio sale de la cotización o del
/// pedido (`transfer`, `mercadopago`, `cash`) y el porcentaje lo informa el back.
String paymentSurchargeLabel(String? method, double? percentage) {
  final medio = switch (method) {
    'transfer' => ' por transferencia',
    'mercadopago' => ' por Mercado Pago',
    'cash' => ' por efectivo',
    _ => ' por medio de pago',
  };
  final pct = percentage == null ? '' : ' (${percentLabel(percentage)} %)';
  return 'Recargo$medio$pct';
}

/// "Envases (2)": la línea del cargo de envases en el desglose.
String containerChargeLabel(int count) => 'Envases ($count)';

/// Por qué se cobran envases: el cliente pide más garrafas que las vacías que
/// tiene para canjear, y los envases que paga pasan a ser suyos.
String containerChargeNote(int count) => count == 1
    ? 'Pedís más garrafas que los envases que tenés: se te cobra 1 envase, '
        'que queda tuyo.'
    : 'Pedís más garrafas que los envases que tenés: se te cobran $count '
        'envases, que quedan tuyos.';

/// "2x Garrafa 10kg" para un renglón del pedido.
String itemLabel(OrderItem item) {
  final type = item.cylinder.type.trim();
  return '${item.quantity}x ${type.isEmpty ? 'Garrafa' : type}';
}

/// "08:00:00" -> "08:00".
String hhmm(String time) {
  final parts = time.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : time;
}
