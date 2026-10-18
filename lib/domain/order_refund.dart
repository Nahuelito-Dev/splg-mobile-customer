/// Estado de una devolución del pago, tal como lo informa el back.
enum RefundStatus {
  /// En trámite con la pasarela.
  pending,

  /// Acreditada al medio de pago original.
  succeeded,

  /// La pasarela la rechazó; todavía no se acreditó y la distribuidora la revisa.
  failed;

  static RefundStatus? fromWire(dynamic raw) => switch (raw) {
        'pending' => RefundStatus.pending,
        'succeeded' => RefundStatus.succeeded,
        'failed' => RefundStatus.failed,
        _ => null,
      };
}

/// Una devolución de un pago online del pedido
/// (`GET /orders/:id/refunds/mine`).
class OrderRefund {
  const OrderRefund({
    required this.expressSurchargeOnly,
    required this.amount,
    required this.status,
    this.requestedAt,
    this.completedAt,
  });

  /// Sólo el recargo express (el pedido pasó al reparto común); si no, es lo
  /// que faltaba devolver del pago porque el pedido se canceló.
  final bool expressSurchargeOnly;
  final double amount;
  final RefundStatus status;
  final DateTime? requestedAt;
  final DateTime? completedAt;

  /// Lee un elemento de la lista; null si no tiene importe o estado legibles.
  static OrderRefund? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final amount = raw['amount'];
    final status = RefundStatus.fromWire(raw['status']);
    final value = amount is num
        ? amount.toDouble()
        : amount is String
            ? double.tryParse(amount)
            : null;
    if (value == null || status == null) return null;
    return OrderRefund(
      expressSurchargeOnly: raw['kind'] == 'express_surcharge',
      amount: value,
      status: status,
      requestedAt: DateTime.tryParse('${raw['requestedAt']}'),
      completedAt: raw['completedAt'] == null
          ? null
          : DateTime.tryParse('${raw['completedAt']}'),
    );
  }

  /// Lee la lista completa; lo ilegible se descarta.
  static List<OrderRefund> listFromJson(dynamic raw) => raw is List
      ? raw.map(fromJson).whereType<OrderRefund>().toList()
      : const <OrderRefund>[];
}
