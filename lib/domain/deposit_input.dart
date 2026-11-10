import 'package:splg_lib/domain/order.dart';

/// Seña de una reserva (CU-072) tal como la tipea el cliente, con las mismas
/// reglas que `CreateOrderDto` del back: número no negativo con hasta dos
/// decimales; con Mercado Pago, mayor a cero (se cobra online y activa la
/// reserva); y sin superar el total del pedido.
class DepositInput {
  const DepositInput._(this.amount, this.error);

  /// Monto listo para mandar; null si hay [error].
  final double? amount;

  /// Texto para el cliente; null si la seña es válida.
  final String? error;

  bool get valid => error == null && amount != null;

  /// [total] es el del pedido cotizado: si se conoce, la seña no lo puede
  /// superar.
  static DepositInput parse(
    String raw, {
    required PaymentMethod method,
    double? total,
    String Function(num)? format,
  }) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      return const DepositInput._(null, 'Indicá el monto de la seña.');
    }
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(text)) {
      return const DepositInput._(null, 'Ingresá un monto válido.');
    }
    final value = double.parse(text);
    if (value < 0) {
      return const DepositInput._(null, 'La seña no puede ser negativa.');
    }
    final decimals = text.contains('.') ? text.split('.').last.length : 0;
    if (decimals > 2) {
      return const DepositInput._(null, 'La seña admite hasta 2 decimales.');
    }
    if (method == PaymentMethod.mercadoPago && value <= 0) {
      return const DepositInput._(null,
          'Con Mercado Pago la seña tiene que ser mayor a cero: se paga online y activa la reserva.');
    }
    if (total != null && value > total) {
      final fmt = format ?? (n) => n.toStringAsFixed(2);
      return DepositInput._(
          null,
          'La seña (${fmt(value)}) no puede superar el total del '
          'pedido (${fmt(total)}).');
    }
    return DepositInput._(value, null);
  }
}
