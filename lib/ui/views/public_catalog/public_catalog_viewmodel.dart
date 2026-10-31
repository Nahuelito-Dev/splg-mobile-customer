import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/gas_cylinder.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';

/// Catálogo para quien todavía no inició sesión: se mira y se arma una
/// selección; para pedir hay que entrar, y la selección viaja al carrito.
class PublicCatalogViewModel extends BaseViewModel {
  final _gasCylinderService = locator<GasCylinderService>();
  final _navigationService = locator<NavigationService>();

  List<GasCylinder> _cylinders = [];
  List<GasCylinder> get cylinders => _cylinders;

  /// Texto de error si no se pudo cargar el catálogo.
  String? loadError;

  final Map<String, int> _selection = {};

  static const _catalogError =
      'No pudimos cargar las garrafas. Probá de nuevo.';

  Future<void> initialize() async {
    setBusy(true);
    loadError = null;
    try {
      _cylinders = await _gasCylinderService.getPublicCatalog();
    } catch (_) {
      loadError = _catalogError;
    }
    setBusy(false);
  }

  String? photo(String id) => _gasCylinderService.photoUrl(id);

  bool soldOut(String id) => _gasCylinderService.outOfStock.contains(id);

  int quantityOf(String id) => _selection[id] ?? 0;

  int get itemCount => _selection.values.fold(0, (a, b) => a + b);

  bool get hasSelection => itemCount > 0;

  /// Texto del botón de abajo: con garrafas elegidas pide; sin ellas, invita a
  /// entrar.
  String get actionLabel => hasSelection
      ? 'Pedir · $itemCount ${itemCount == 1 ? 'garrafa' : 'garrafas'}'
      : 'Iniciar sesión o registrarme';

  /// Suma o resta una unidad en la selección (no toca ningún carrito). Una
  /// garrafa sin stock no se suma.
  void change(GasCylinder cylinder, int delta) {
    if (delta > 0 && soldOut(cylinder.id)) return;
    final next = quantityOf(cylinder.id) + delta;
    if (next <= 0) {
      _selection.remove(cylinder.id);
    } else {
      _selection[cylinder.id] = next;
    }
    rebuildUi();
  }

  /// Guarda la selección y lleva al login. Al entrar, el inicio la pasa al
  /// carrito del back.
  Future<void> continueToLogin() async {
    _gasCylinderService.savePendingSelection(_selection);
    await _navigationService.navigateToLoginView();
  }

  void back() => _navigationService.back();
}
