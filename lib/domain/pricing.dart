import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_lib/domain/order_item.dart';

/// Precio de las garrafas con la promoción por cantidad. La promoción que se
/// aplica es la de mayor umbral que la cantidad alcanza, sin depender del
/// orden en que el back mande la lista.
class Pricing {
  Pricing._();

  /// Promociones ordenadas de menor a mayor cantidad.
  static List<Discount> sortedDiscounts(GasCylinder cylinder) => [
        ...?cylinder.discounts
      ]..sort((a, b) => a.quantity.compareTo(b.quantity));

  static Discount? applied(GasCylinder cylinder, int quantity) {
    Discount? best;
    for (final d in sortedDiscounts(cylinder)) {
      if (quantity >= d.quantity) best = d;
    }
    return best;
  }

  static double subtotal(OrderItem item) {
    final base = item.cylinder.price * item.quantity;
    final d = applied(item.cylinder, item.quantity);
    return d == null ? base : base * (1 - d.percentage / 100);
  }

  /// "−12% x4" para las insignias del catálogo.
  static String badge(Discount d) =>
      '−${d.percentage.toStringAsFixed(0)}% x${d.quantity}';
}
