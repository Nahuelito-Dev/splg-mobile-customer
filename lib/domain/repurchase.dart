// Recompra anticipada (M3, CU-106, CU-145 y CU-146): lo que el back manda en
// `/api/v2/customers/me/repurchase`.

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

double _number(Object? raw) => raw is num
    ? raw.toDouble()
    : (raw is String ? double.tryParse(raw) ?? 0 : 0);

String? _text(Object? raw) {
  final t = raw?.toString().trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Una garrafa del pedido precargado de la invitación.
class RepurchaseItem {
  const RepurchaseItem({
    required this.gasCylinderId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.available,
  });

  final String gasCylinderId;

  /// Nombre del tipo, p. ej. `10kg`.
  final String type;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  /// false: el producto se dio de baja o ya no hay stock para la cantidad.
  final bool available;

  static RepurchaseItem? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = _text(json['gasCylinderId']);
    if (id == null) return null;
    return RepurchaseItem(
      gasCylinderId: id,
      type: _text(json['type']) ?? '',
      quantity: _number(json['quantity']).round(),
      unitPrice: _number(json['unitPrice']),
      subtotal: _number(json['subtotal']),
      available: json['available'] != false,
    );
  }
}

/// Franja horaria sugerida (sin fecha: la entrega la agenda el back).
class RepurchaseSlot {
  const RepurchaseSlot({
    required this.timeSlotId,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  final String timeSlotId;
  final String name;
  final String startTime;
  final String endTime;

  String get label => '$name · $startTime a $endTime';
}

enum RepurchaseStatus {
  pending,
  accepted,
  rejected,
  expired,
  cancelled;

  static RepurchaseStatus parse(Object? raw) => switch (raw) {
        'accepted' => accepted,
        'rejected' => rejected,
        'expired' => expired,
        'cancelled' => cancelled,
        _ => pending,
      };
}

/// La invitación a reponer, con el pedido precargado a precios de hoy.
class RepurchaseInvitation {
  const RepurchaseInvitation({
    required this.invitationId,
    required this.status,
    required this.items,
    required this.estimatedTotal,
    required this.expiresAt,
    this.projectedDepletionAt,
    this.distributorId,
    this.paymentMethod,
    this.addressId,
    this.addressLabel,
    this.slot,
    this.orderId,
  });

  final String invitationId;
  final RepurchaseStatus status;
  final List<RepurchaseItem> items;

  /// Cantidad por precio de lista de hoy: sin promociones ni recargos.
  final double estimatedTotal;
  final DateTime expiresAt;
  final DateTime? projectedDepletionAt;

  /// Distribuidora de la invitación: va en `X-Distributor` al cotizar.
  final String? distributorId;

  /// Medio de pago de la invitación tal como viaja (`cash`, `transfer`,
  /// `mercadopago`): con ese se crea el pedido al aceptarla.
  final String? paymentMethod;

  /// La dirección de la invitación (la de su última compra): el back la usa
  /// si al aceptar no se manda otra.
  final String? addressId;
  final String? addressLabel;
  final RepurchaseSlot? slot;
  final String? orderId;

  /// Alguna garrafa ya no se puede pedir (el back rechaza el alta).
  bool get hasUnavailable => items.any((i) => !i.available);

  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  /// Abierta y todavía vigente.
  bool isOpenAt(DateTime now) =>
      status == RepurchaseStatus.pending && expiresAt.isAfter(now);

  /// "2 × 10kg · 1 × 45kg".
  String get itemsLabel =>
      items.map((i) => '${i.quantity} × ${i.type}').join(' · ');

  static RepurchaseInvitation? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = _text(json['invitationId']);
    final expires = _date(json['expiresAt']);
    if (id == null || expires == null) return null;
    final rawItems = json['items'];
    final address = json['address'];
    final slot = json['timeSlot'];
    return RepurchaseInvitation(
      invitationId: id,
      status: RepurchaseStatus.parse(json['status']),
      items: rawItems is List
          ? [
              for (final i in rawItems)
                if (RepurchaseItem.fromJson(i) case final item?) item
            ]
          : const [],
      estimatedTotal: _number(json['estimatedTotal']),
      expiresAt: expires,
      projectedDepletionAt: _date(json['projectedDepletionAt']),
      distributorId: _text(json['distributorId']),
      paymentMethod: _text(json['paymentMethod']),
      addressId: address is Map ? _text(address['addressId']) : null,
      addressLabel: address is Map ? _text(address['label']) : null,
      slot: slot is Map && _text(slot['timeSlotId']) != null
          ? RepurchaseSlot(
              timeSlotId: slot['timeSlotId'].toString(),
              name: _text(slot['name']) ?? '',
              startTime: _text(slot['startTime']) ?? '',
              endTime: _text(slot['endTime']) ?? '',
            )
          : null,
      orderId: _text(json['orderId']),
    );
  }
}

/// Aviso de recompra del cliente (CU-145).
class RepurchaseNotice {
  const RepurchaseNotice({
    this.enabled = true,
    this.days,
    this.distributorDays,
    this.effectiveDays,
  });

  final bool enabled;

  /// Los días que eligió; null = rige el de la distribuidora.
  final int? days;
  final int? distributorDays;
  final int? effectiveDays;

  bool get usesDistributorDays => days == null;

  static RepurchaseNotice? fromJson(dynamic json) {
    if (json is! Map) return null;
    int? n(Object? v) => v is num ? v.round() : null;
    return RepurchaseNotice(
      enabled: json['enabled'] != false,
      days: n(json['days']),
      distributorDays: n(json['distributorDays']),
      effectiveDays: n(json['effectiveDays']),
    );
  }
}

/// Mi fecha estimada de recompra con la distribuidora (CU-146).
class RepurchaseForecast {
  const RepurchaseForecast({
    this.estimatedAt,
    this.daysLeft,
    this.reason,
    this.notice = const RepurchaseNotice(),
    this.openInvitation,
  });

  final DateTime? estimatedAt;
  final int? daysLeft;

  /// Por qué no hay fecha: `no_purchases`, `insufficient_history`,
  /// `irregular_history` o `stale`.
  final String? reason;
  final RepurchaseNotice notice;
  final RepurchaseInvitation? openInvitation;

  /// Texto para el cliente cuando no hay fecha.
  String get reasonText => switch (reason) {
        'no_purchases' => 'Todavía no hiciste pedidos con nosotros.',
        'insufficient_history' =>
          'Todavía no tenemos pedidos suficientes para estimarlo.',
        'irregular_history' =>
          'Tus pedidos son muy distintos entre sí: no podemos estimarlo.',
        'stale' => 'Hace tiempo que no pedís: no podemos estimarlo.',
        _ => 'Todavía no podemos estimar tu próxima recompra.',
      };

  static RepurchaseForecast? fromJson(dynamic json) {
    if (json is! Map) return null;
    final days = json['daysLeft'];
    return RepurchaseForecast(
      estimatedAt: _date(json['estimatedAt']),
      daysLeft: days is num ? days.round() : null,
      reason: _text(json['reason']),
      notice: RepurchaseNotice.fromJson(json['notice']) ??
          const RepurchaseNotice(),
      openInvitation: RepurchaseInvitation.fromJson(json['openInvitation']),
    );
  }
}

/// Lo que devuelve aceptar la invitación: el pedido que se creó.
class RepurchaseAccepted {
  const RepurchaseAccepted({required this.orderId, this.paymentUrl});

  final String orderId;

  /// Sólo con Mercado Pago.
  final String? paymentUrl;

  static RepurchaseAccepted? fromJson(dynamic json) {
    if (json is! Map) return null;
    final order = json['order'];
    final invitation = json['invitation'];
    final id = order is Map
        ? (_text(order['orderId']) ?? _text(order['order_id']) ?? _text(order['id']))
        : null;
    final fallback = invitation is Map ? _text(invitation['orderId']) : null;
    final orderId = id ?? fallback;
    if (orderId == null) return null;
    return RepurchaseAccepted(
      orderId: orderId,
      paymentUrl: order is Map ? _text(order['paymentUrl']) : null,
    );
  }
}

/// Días de aviso válidos (CU-145): enteros de 1 a 30.
const repurchaseNoticeMinDays = 1;
const repurchaseNoticeMaxDays = 30;

/// Días tal como los escribe el cliente; null si no sirven.
int? parseNoticeDays(String raw) {
  final text = raw.trim();
  if (!RegExp(r'^\d{1,3}$').hasMatch(text)) return null;
  final value = int.parse(text);
  if (value < repurchaseNoticeMinDays || value > repurchaseNoticeMaxDays) {
    return null;
  }
  return value;
}
