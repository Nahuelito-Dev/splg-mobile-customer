import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_quote.dart';

/// Vista previa de la compra express de un toque
/// (`POST /orders/express/quote`, CU-147): la dirección predeterminada, lo que
/// se compra y el precio final con el recargo express. Si no hay cobertura,
/// horario o moto, [available] es false y el back sugiere el reparto común.
class ExpressPreview {
  const ExpressPreview({
    required this.available,
    this.reason,
    this.message,
    this.addressText,
    this.gasCylinderId,
    this.quantity = 1,
    this.quote,
    this.estimatedMinutes,
  });

  final bool available;
  final String? reason;
  final String? message;

  /// "Calle 123, Localidad".
  final String? addressText;
  final String? gasCylinderId;
  final int quantity;
  final OrderQuote? quote;
  final int? estimatedMinutes;

  /// Por qué no se puede, con el texto listo para el cliente.
  String get unavailableText => expressUnavailableText(reason, message);

  static ExpressPreview? fromJson(dynamic raw) {
    if (raw is! Map || raw['available'] is! bool) return null;
    final address = raw['address'];
    final item = raw['item'];
    final street = address is Map ? address['street']?.toString() : null;
    final city = address is Map ? address['city']?.toString() : null;
    final minutes = raw['estimatedMinutes'];
    return ExpressPreview(
      available: raw['available'] as bool,
      reason: raw['reason']?.toString(),
      message: raw['message']?.toString(),
      addressText: [street, city]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .join(', '),
      gasCylinderId: item is Map ? item['gasCylinderId']?.toString() : null,
      quantity: item is Map && item['quantity'] is num
          ? (item['quantity'] as num).toInt()
          : 1,
      quote: OrderQuote.fromJson(raw['quote']),
      estimatedMinutes: minutes is num ? minutes.toInt() : null,
    );
  }
}
