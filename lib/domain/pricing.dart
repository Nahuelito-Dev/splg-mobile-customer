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

  /// Precio unitario con la promoción, redondeado a centavos como el back
  /// (`OrderPricingService.priceItem`): el subtotal sale de este precio.
  static double unitPrice(GasCylinder cylinder, int quantity) {
    final d = applied(cylinder, quantity);
    final cents = (cylinder.price * 100).round();
    final unit =
        d == null ? cents : (cents * (100 - d.percentage) / 100).round();
    return unit / 100;
  }

  /// Subtotal de un renglón sobre el PRECIO DE LISTA del producto. Para
  /// mostrar lo que cobra el pedido usá [charged].
  static double subtotal(OrderItem item) =>
      (unitPrice(item.cylinder, item.quantity) * 100).round() *
      item.quantity /
      100;

  /// Subtotal de un renglón de un pedido ya armado: su precio unitario es el
  /// que guardó el back (promoción incluida), así que no se descuenta de nuevo.
  static double charged(OrderItem item) =>
      (item.cylinder.price * 100).round() * item.quantity / 100;

  /// "−12% x4" para las insignias del catálogo.
  static String badge(Discount d) =>
      '−${d.percentage.toStringAsFixed(0)}% x${d.quantity}';
}
