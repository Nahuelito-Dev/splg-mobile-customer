/// Modalidad de entrega de un pedido (`deliveryMode` del back).
enum DeliveryMode {
  standard,
  express;

  /// Valor que viaja al back.
  String get wire => name;

  static DeliveryMode fromWire(Object? raw) => raw?.toString() == 'express'
      ? DeliveryMode.express
      : DeliveryMode.standard;
}

/// Texto para el cliente según el `reason` por el que el express no está
/// disponible (`GET /orders/delivery-options`, 409 `EXPRESS_NOT_AVAILABLE`).
/// Un motivo que la app no conoce usa el mensaje del back, y sin él uno propio.
String expressUnavailableText(String? reason, [String? backMessage]) {
  switch (reason) {
    case 'disabled':
      return 'Tu distribuidora no ofrece entrega express.';
    case 'no_location':
      return 'Esta dirección no tiene ubicación en el mapa: editala para '
          'poder pedir express.';
    case 'out_of_coverage':
      return 'Esta dirección está fuera de la zona del servicio express.';
    case 'out_of_hours':
      return 'El servicio express está fuera de horario.';
    case 'no_motorcycle_driver':
      return 'No hay un repartidor en moto disponible cerca.';
  }
  final message = backMessage?.trim();
  return message == null || message.isEmpty
      ? 'La entrega express no está disponible en este momento.'
      : message;
}

/// Una modalidad ofrecida para una dirección, con su recargo y su demora.
class DeliveryOption {
  const DeliveryOption({
    required this.mode,
    required this.available,
    this.reason,
    this.message,
    this.surchargeAmount = 0,
    this.estimatedMinutes,
  });

  final DeliveryMode mode;
  final bool available;

  /// Por qué no está disponible (`disabled`, `out_of_hours`, ...).
  final String? reason;
  final String? message;
  final double surchargeAmount;
  final int? estimatedMinutes;

  /// Texto de por qué no se puede elegir; null si está disponible.
  String? get unavailableText =>
      available ? null : expressUnavailableText(reason, message);
}

/// Modalidades que ofrece la distribuidora para una dirección
/// (`GET /orders/delivery-options?addressId=`).
class DeliveryOptions {
  const DeliveryOptions(this.options);

  final List<DeliveryOption> options;

  DeliveryOption? optionFor(DeliveryMode mode) {
    for (final o in options) {
      if (o.mode == mode) return o;
    }
    return null;
  }

  /// Si la distribuidora ofrece la modalidad express para esta dirección. Sin
  /// la opción en la respuesta no se muestra nada que elegir.
  bool get hasExpress => optionFor(DeliveryMode.express) != null;

  /// Lee la respuesta del back; null si no trae la lista de opciones.
  static DeliveryOptions? fromJson(dynamic raw) {
    if (raw is! Map || raw['options'] is! List) return null;
    return DeliveryOptions([
      for (final o in raw['options'] as List)
        if (o is Map)
          DeliveryOption(
            mode: DeliveryMode.fromWire(o['mode']),
            available: o['available'] == true,
            reason: o['reason']?.toString(),
            message: o['message']?.toString(),
            surchargeAmount: _num(o['surchargeAmount']) ?? 0,
            estimatedMinutes: _num(o['estimatedMinutes'])?.toInt(),
          ),
    ]);
  }

  static double? _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
}
