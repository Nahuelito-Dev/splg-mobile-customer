import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Mi carrito: lo que guarda el back, con total, avisos de precio, de ítems
/// dados de baja y de stock. Toda acción vuelve a mostrar lo que devuelve el
/// back; si falla, el carrito queda como estaba y se muestra el motivo.
class CartViewModel extends LoadViewModel {
  final _cartService = locator<CartService>();
  final _nav = locator<NavigationService>();

  /// Lo que devuelve el carrito al Inicio para que abra el catálogo.
  static const addMoreResult = 'agregar-garrafas';

  /// Vuelve al Inicio con el catálogo abierto para sumar garrafas.
  void addMore() => _nav.back(result: addMoreResult);

  Cart get cart => _cartService.cart;

  /// Error de la última acción (cambiar cantidad, quitar, vaciar).
  String? actionError;

  /// Se puede seguir a la confirmación: hay ítems y todos están disponibles.
  bool get canContinue => !cart.isEmpty && !cart.hasUnavailableItems;

  @override
  Future<void> fetch() async {
    final r = await _cartService.refresh();
    if (!r.ok) throw LoadFailure(r.message!);
  }

  Future<void> _act(Future<dynamic> Function() action) async {
    if (isBusy) return;
    actionError = null;
    setBusy(true);
    final r = await action();
    if (!r.ok) actionError = r.message;
    setBusy(false);
  }

  Future<void> increment(CartLine line) =>
      _act(() => _cartService.setQuantity(line.cartItemId, line.quantity + 1));

  /// Con una sola unidad no baja a cero: el back lo rechaza y quitar es otra
  /// acción ([remove]).
  Future<void> decrement(CartLine line) async {
    if (line.quantity <= 1) return;
    await _act(
        () => _cartService.setQuantity(line.cartItemId, line.quantity - 1));
  }

  Future<void> remove(CartLine line) =>
      _act(() => _cartService.remove(line.cartItemId));

  Future<void> clear() => _act(_cartService.clear);

  Future<void> goToCheckout() async {
    if (!canContinue) return;
    await _nav.navigateToCheckoutView();
    // Al volver el carrito pudo haberse vaciado con un pedido.
    notifyListeners();
  }
}
