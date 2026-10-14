/// Renglón de la cotización: precio unitario con la promoción por volumen ya
/// aplicada por el back.
class QuoteLine {
  const QuoteLine({
    required this.gasCylinderId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String gasCylinderId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
}

/// Cotización de un pedido (`POST /orders/quote`): el desglose que después
/// cobra `POST /orders`. Todo el precio lo calcula el back (promociones por
/// volumen, recargo de zona y por medio de pago); la app sólo lo muestra.
class OrderQuote {
  const OrderQuote({
    required this.lines,
    required this.subtotal,
    required this.zoneSurcharge,
    required this.paymentSurcharge,
    required this.deposit,
    required this.total,
    required this.balance,
    this.zoneName,
  });

  final List<QuoteLine> lines;
  final double subtotal;
  final double zoneSurcharge;
  final String? zoneName;
  final double paymentSurcharge;
  final double deposit;
  final double total;
  final double balance;

  /// Lee la respuesta del back; null si no trae un `total` numérico (no se
  /// inventa un precio con una respuesta ilegible).
  static OrderQuote? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final total = _num(raw['total']);
    if (total == null) return null;
    final zone = raw['zone'];
    return OrderQuote(
      lines: [
        for (final l
            in (raw['items'] is List ? raw['items'] as List : const []))
          if (l is Map) _line(l),
      ],
      subtotal: _num(raw['subtotal']) ?? total,
      zoneSurcharge: _num(raw['zoneSurcharge']) ?? 0,
      zoneName: zone is Map ? zone['name']?.toString() : null,
      paymentSurcharge: _num(raw['paymentSurcharge']) ?? 0,
      deposit: _num(raw['deposit']) ?? 0,
      total: total,
      balance: _num(raw['balance']) ?? total,
    );
  }

  /// El renglón de esa garrafa, o null.
  QuoteLine? lineFor(String gasCylinderId) {
    for (final l in lines) {
      if (l.gasCylinderId == gasCylinderId) return l;
    }
    return null;
  }

  static QuoteLine _line(Map l) => QuoteLine(
        gasCylinderId: l['gasCylinderId']?.toString() ?? '',
        quantity: (_num(l['quantity']) ?? 0).toInt(),
        unitPrice: _num(l['unitPrice']) ?? 0,
        subtotal: _num(l['subtotal']) ?? 0,
      );

  static double? _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
}

/// Resultado de pedir una cotización: la cotización, o el texto para el
/// usuario (el del back si es una regla de negocio, como "sin stock" o "fuera
/// de la zona de cobertura").
class QuoteOutcome {
  const QuoteOutcome.ok(OrderQuote this.quote)
      : message = null,
        retryable = false;

  const QuoteOutcome.failed(String this.message, {this.retryable = true})
      : quote = null;

  final OrderQuote? quote;
  final String? message;

  /// Volver a pedirla puede funcionar (red, 429, 5xx).
  final bool retryable;

  bool get ok => quote != null;
}
