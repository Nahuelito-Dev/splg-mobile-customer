import 'package:splg_customer/ui/common/formatters.dart';

/// Un medio de pago de la distribuidora con el recargo (%) que cobra hoy: lo
/// informa el back (`GET /v2/public/distributors/:slug/payment-methods`). Es
/// informativo; el monto exacto de un pedido lo da la cotización.
class PaymentTerm {
  const PaymentTerm(
      {required this.key, required this.name, required this.percentage});

  /// `CASH`, `TRANSFER` o `MERCADOPAGO`.
  final String key;
  final String name;
  final double percentage;

  bool get hasSurcharge => percentage > 0;

  /// "10 %" / "7,5 %".
  String get percentageLabel => '${percentLabel(percentage)} %';

  /// La lista tal como la devuelve el back; lo ilegible se descarta.
  static List<PaymentTerm> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <PaymentTerm>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final pct = e['surcharge'];
      final key = e['key']?.toString();
      if (key == null || pct is! num) continue;
      out.add(PaymentTerm(
          key: key,
          name: e['name']?.toString() ?? key,
          percentage: pct.toDouble()));
    }
    return out;
  }

  /// El de ese medio, o null si el back no lo informó.
  static PaymentTerm? of(List<PaymentTerm> terms, String key) {
    for (final t in terms) {
      if (t.key == key) return t;
    }
    return null;
  }
}
