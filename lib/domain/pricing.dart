import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';

/// Cómo se muestran las promociones por cantidad. Los precios con promoción
/// los calcula el back (cada promoción trae su `unitPrice`): acá no se hace
/// ninguna cuenta de plata.
class Pricing {
  Pricing._();

  /// Los precios que cobra el sistema son finales: el IVA ya está incluido.
  static const ivaIncluido = 'Precios finales con IVA incluido.';

  /// Promociones ordenadas de menor a mayor cantidad.
  static List<Discount> sortedDiscounts(GasCylinder cylinder) => [
        ...?cylinder.discounts
      ]..sort((a, b) => a.quantity.compareTo(b.quantity));

  /// "−12% x4" para las insignias del catálogo.
  static String badge(Discount d) =>
      '−${d.percentage.toStringAsFixed(0)}% x${d.quantity}';
}
