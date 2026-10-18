/// Consumo promedio declarado por el cliente (`GET /customers/me/consumption`).
class Consumption {
  const Consumption({
    this.cylinderTypeId,
    this.cylinderType,
    this.avgMonthlyConsumptionKg,
    this.nextRepurchaseEstimateAt,
  });

  final String? cylinderTypeId;

  /// Nombre del tipo habitual, p. ej. `10kg`.
  final String? cylinderType;
  final double? avgMonthlyConsumptionKg;
  final DateTime? nextRepurchaseEstimateAt;

  bool get declared => avgMonthlyConsumptionKg != null;

  static Consumption? fromJson(dynamic json) {
    if (json is! Map) return null;
    final kg = json['avgMonthlyConsumptionKg'];
    final next = json['nextRepurchaseEstimateAt'];
    return Consumption(
      cylinderTypeId: json['cylinderTypeId'] as String?,
      cylinderType: json['cylinderType'] as String?,
      avgMonthlyConsumptionKg: kg is num
          ? kg.toDouble()
          : (kg is String ? double.tryParse(kg) : null),
      nextRepurchaseEstimateAt:
          next is String ? DateTime.tryParse(next)?.toLocal() : null,
    );
  }
}

/// Lo que el cliente declara: garrafas por mes de un tipo. El back lo pasa a
/// kilos con el peso del tipo.
class ConsumptionDeclaration {
  const ConsumptionDeclaration({
    this.cylinderTypeId,
    required this.quantityPerMonth,
    this.confirmOutOfRange = false,
  });

  final String? cylinderTypeId;
  final double quantityPerMonth;
  final bool confirmOutOfRange;

  ConsumptionDeclaration confirmed() => ConsumptionDeclaration(
        cylinderTypeId: cylinderTypeId,
        quantityPerMonth: quantityPerMonth,
        confirmOutOfRange: true,
      );

  Map<String, dynamic> toJson() => {
        if (cylinderTypeId != null) 'cylinderTypeId': cylinderTypeId,
        'quantityPerMonth': quantityPerMonth,
        if (confirmOutOfRange) 'confirmOutOfRange': true,
      };
}

/// El 400 con el que el back pide confirmar un consumo fuera del rango
/// razonable (5 a 500 kg por mes).
bool isConsumptionOutOfRange(int? status, dynamic data) {
  if (status != 400 || data is! Map) return false;
  final message = data['message'];
  final text = message is List ? message.join(' ') : message?.toString() ?? '';
  return text.contains('fuera del rango razonable');
}

/// Rango razonable que valida el back, en kilos por mes.
const consumptionMinKg = 5;
const consumptionMaxKg = 500;

/// Garrafas por mes tal como las escribe el cliente ("2", "1,5"): de 0,01 a
/// 1000 con hasta 2 decimales, como lo valida el back. Null si no sirve.
double? parseQuantityPerMonth(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
  final value = double.tryParse(text);
  if (value == null || value < 0.01 || value > 1000) return null;
  return value;
}
