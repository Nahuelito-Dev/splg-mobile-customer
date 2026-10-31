import 'package:splg_lib/splg_lib.dart';

abstract interface class GasCylinderRepository {
  Future<List<GasCylinder>> getGasCylinders();

  /// El catálogo de la distribuidora para quien todavía no inició sesión.
  Future<List<GasCylinder>> getPublicCatalog();

  /// Ids de las garrafas del último catálogo público que no tienen stock.
  Set<String> get outOfStock;
}
