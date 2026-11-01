// Recupero de envases no devueltos (M5, CU-108): lo que el back manda en
// `/api/v2/cylinder-recovery/mine`.

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

String? _text(Object? raw) {
  final t = raw?.toString().trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// La oferta de retiro del envase en la próxima entrega.
class RecoveryPickup {
  const RecoveryPickup({
    required this.noticeId,
    required this.accepted,
    required this.orderId,
    this.scheduledDate,
    this.expiresAt,
  });

  final String noticeId;

  /// true: el cliente ya la aceptó; false: espera su respuesta.
  final bool accepted;
  final String orderId;

  /// Día agendado de la entrega (`YYYY-MM-DD`).
  final String? scheduledDate;
  final DateTime? expiresAt;

  static RecoveryPickup? fromJson(dynamic json) {
    if (json is! Map) return null;
    final noticeId = _text(json['noticeId']);
    final orderId = _text(json['orderId']);
    if (noticeId == null || orderId == null) return null;
    return RecoveryPickup(
      noticeId: noticeId,
      accepted: json['status'] == 'accepted',
      orderId: orderId,
      scheduledDate: _text(json['scheduledDate']),
      expiresAt: _date(json['expiresAt']),
    );
  }
}

/// Un envase que el cliente tiene y todavía no devolvió.
class RecoveryCase {
  const RecoveryCase({
    required this.caseId,
    required this.serial,
    required this.step,
    required this.depositAmount,
    required this.daysOut,
    this.product,
    this.pickup,
  });

  final String caseId;

  /// Número del envase, p. ej. `SPLG-00197`.
  final String serial;
  final String? product;

  /// 1 recordatorio, 2 aviso del depósito, 3 secuencia agotada.
  final int step;
  final double depositAmount;
  final int daysOut;
  final RecoveryPickup? pickup;

  static RecoveryCase? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = _text(json['caseId']);
    final cylinder = json['cylinder'];
    final serial = cylinder is Map ? _text(cylinder['serial']) : null;
    if (id == null || serial == null) return null;
    final deposit = json['depositAmount'];
    final step = json['step'];
    final days = json['daysOut'];
    return RecoveryCase(
      caseId: id,
      serial: serial,
      product: cylinder is Map ? _text(cylinder['product']) : null,
      step: step is num ? step.round() : 1,
      depositAmount: deposit is num
          ? deposit.toDouble()
          : (deposit is String ? double.tryParse(deposit) ?? 0 : 0),
      daysOut: days is num ? days.round() : 0,
      pickup: RecoveryPickup.fromJson(json['pickup']),
    );
  }
}

/// El retiro aceptado que lleva el [orderId] (null si ese pedido no lleva
/// ninguno): el aviso del seguimiento.
RecoveryCase? pickupForOrder(List<RecoveryCase> cases, String orderId) {
  for (final c in cases) {
    final p = c.pickup;
    if (p != null && p.accepted && p.orderId == orderId) return c;
  }
  return null;
}
