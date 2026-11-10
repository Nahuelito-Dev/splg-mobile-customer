/// Un renglón del historial de estados del pedido
/// (`GET /orders/:id/status-history`, CU-170): del más viejo al más nuevo.
class OrderStatusEntry {
  const OrderStatusEntry({
    required this.toStatus,
    required this.changedAt,
    this.fromStatus,
    this.isNote = false,
    this.reason,
  });

  final String? fromStatus;
  final String toStatus;

  /// Anotación de un cobro manual (origen = destino), no un cambio de estado.
  final bool isNote;
  final String? reason;
  final DateTime changedAt;

  /// Texto del estado para el cliente.
  static String statusText(String status) => switch (status) {
        'reserved' => 'Reservado',
        'pending' => 'Pendiente',
        'accepted' => 'Asignado',
        'out_for_delivery' || 'on_the_way' => 'En camino',
        'delivered' => 'Entregado',
        'cancelled' => 'Cancelado',
        _ => status,
      };

  String get title => isNote ? 'Nota' : statusText(toStatus);

  static OrderStatusEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final to = raw['toStatus']?.toString();
    final at = DateTime.tryParse(raw['changedAt']?.toString() ?? '');
    if (to == null || to.isEmpty || at == null) return null;
    final reason = raw['reason']?.toString().trim();
    return OrderStatusEntry(
      fromStatus: raw['fromStatus']?.toString(),
      toStatus: to,
      isNote: raw['isNote'] == true,
      reason: reason == null || reason.isEmpty ? null : reason,
      changedAt: at,
    );
  }

  static List<OrderStatusEntry> listFromJson(dynamic raw) => [
        if (raw is List)
          for (final e in raw)
            if (fromJson(e) case final entry?) entry,
      ];
}
