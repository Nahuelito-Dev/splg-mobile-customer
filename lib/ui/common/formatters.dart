import 'package:intl/intl.dart';
import 'package:splg_lib/splg_lib.dart';

final money = NumberFormat.currency(
  locale: 'es_AR',
  symbol: '\$',
  decimalDigits: 0,
  customPattern: '¤#,##0',
);

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
