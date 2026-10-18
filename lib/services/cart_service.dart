import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:stacked/stacked.dart';

import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_lib/network/api_error_text.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/cart_remote_datasource.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/services/customer_service.dart';

/// El carrito del cliente. Vive en el back (`/cart`): la app lo trae, muestra
/// lo que éste devuelve y no guarda una copia propia que pueda divergir. Si una
/// llamada falla queda el último carrito que mandó el back, con el error para
/// mostrar. La dirección de entrega sí es de la app (todavía no es un pedido).
class CartService with ListenableServiceMixin {
  /// [datasource] y [tokenReader] sólo se inyectan en los tests.
  CartService({
    CartRemoteDatasource? datasource,
    Future<String?> Function()? tokenReader,
  })  : _remote = datasource ?? CartRemoteDatasource(),
        _tokenReader = tokenReader {
    listenToReactiveValues([_cart, _address]);
  }

  final CartRemoteDatasource _remote;
  final Future<String?> Function()? _tokenReader;

  final ReactiveValue<Cart> _cart = ReactiveValue(Cart.empty);
  final ReactiveValue<Address?> _address = ReactiveValue(null);

  /// Época de la sesión: `reset()` la incrementa y las respuestas de antes del
  /// cierre de sesión se descartan.
  int _session = 0;

  /// Las escrituras se hacen de a una, en el orden en que se tocaron: dos taps
  /// seguidos no se pisan.
  Future<void> _tail = Future.value();

  Cart get cart => _cart.value;
  Address? get address => _address.value;

  int get itemCount => cart.units;
  int quantityOf(String gasCylinderId) => cart.quantityOf(gasCylinderId);

  /// El carrito armado como pedido para cotizar y confirmar; null si no tiene
  /// ítems. El precio de cada ítem es el vigente del catálogo.
  Order? get order {
    final c = cart;
    if (c.isEmpty) return null;
    return Order(
      id: c.cartId ?? 'cart',
      address: address,
      items: [
        for (final line in c.items)
          OrderItem(
            cylinder: GasCylinder(
              id: line.gasCylinderId,
              type: line.type,
              price: line.currentUnitPrice,
              active: line.available,
              weight: '',
              description: '',
            ),
            quantity: line.quantity,
          ),
      ],
      total: c.total,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Deja el carrito y la dirección como se indica, sin pasar por el back.
  @visibleForTesting
  void seed({Cart? cart, Address? address}) {
    if (cart != null) _cart.value = cart;
    _address.value = address;
    notifyListeners();
  }

  void setAddress(Address? address) {
    _address.value = address;
    notifyListeners();
  }

  /// Olvida todo lo del usuario (cierre de sesión o baja de cuenta).
  void reset() {
    _session++;
    _cart.value = Cart.empty;
    _address.value = null;
    notifyListeners();
  }

  /// `GET /cart` (CU-125).
  Future<ApiResult<void>> refresh() => _write((t) => _remote.fetch(t));

  /// `POST /cart/items` (CU-122): suma [quantity] al ítem de ese tipo.
  Future<ApiResult<void>> add(String gasCylinderId, int quantity) =>
      _write((t) => _remote.add(gasCylinderId, quantity, t));

  /// `PATCH /cart/items/:id` (CU-123): deja el ítem con [quantity] (mínimo 1).
  Future<ApiResult<void>> setQuantity(String cartItemId, int quantity) =>
      _write((t) => _remote.setQuantity(cartItemId, quantity, t));

  /// `DELETE /cart/items/:id` (CU-124).
  Future<ApiResult<void>> remove(String cartItemId) =>
      _write((t) => _remote.remove(cartItemId, t));

  /// `DELETE /cart` (CU-126).
  Future<ApiResult<void>> clear() => _write((t) => _remote.clear(t));

  /// Resta una unidad al tipo: con una sola, lo quita.
  Future<ApiResult<void>> removeOne(String gasCylinderId) {
    final line = cart.lineFor(gasCylinderId);
    if (line == null) return Future.value(const ApiResult.ok());
    return line.quantity > 1
        ? setQuantity(line.cartItemId, line.quantity - 1)
        : remove(line.cartItemId);
  }

  /// Arma el carrito con los ítems de [items] (repetir un pedido): lo vacía y
  /// los agrega. Se corta en el primer error.
  Future<ApiResult<void>> replaceWith(List<OrderItem> items) async {
    var result = await clear();
    if (!result.ok) return result;
    for (final item in items.where((i) => i.quantity > 0)) {
      result = await add(item.cylinder.id, item.quantity);
      if (!result.ok) return result;
    }
    return result;
  }

  Future<ApiResult<void>> _write(
      Future<ApiResult<dynamic>> Function(String token) call) {
    final session = _session;
    final turn = _tail.then((_) => _apply(session, call));
    _tail = turn.then((_) {}, onError: (_) {});
    return turn;
  }

  Future<ApiResult<void>> _apply(int session,
      Future<ApiResult<dynamic>> Function(String token) call) async {
    // Pedida por una sesión que ya terminó: no se manda con la del que sigue.
    if (session != _session) {
      return const ApiResult.fail(ApiErrorText.sessionExpired);
    }
    final reader = _tokenReader;
    final token = reader != null
        ? await reader()
        : await locator<CustomerService>().token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final result = await call(token);
    if (!result.ok) {
      return ApiResult.fail(result.message ?? ApiErrorText.generic,
          status: result.status);
    }
    final next = Cart.fromJson(result.data);
    if (next == null) return const ApiResult.fail(ApiErrorText.generic);
    if (session == _session) {
      _cart.value = next;
      notifyListeners();
    }
    return const ApiResult.ok();
  }
}
