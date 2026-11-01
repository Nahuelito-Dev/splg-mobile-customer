import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:splg_lib/domain/discount.dart';

Address addr(String id, String street, {bool primary = false, String? city}) =>
    Address(addressId: id, streetName: street, primary: primary, city: city);

Customer customerWith([List<Address> addresses = const []]) => Customer(
      customerId: 'u1',
      fullName: 'Ana Pérez',
      email: 'ana@splg.com',
      phoneNumber: '+5493815550003',
      blocked: false,
      addresses: addresses,
    );

GasCylinder cylinder({
  String id = 'g1',
  String type = 'Garrafa 10kg',
  double price = 1000,
  List<Discount>? discounts,
}) =>
    GasCylinder(
      id: id,
      type: type,
      weight: '10',
      price: price,
      active: true,
      description: '',
      discounts: discounts,
    );

Order order({
  String id = 'o1',
  OrderStatus status = OrderStatus.pending,
  Address? address,
  List<OrderItem>? items,
  double total = 1000,
  PaymentMethod paymentMethod = PaymentMethod.cash,
}) =>
    Order(
      id: id,
      address: address ?? addr('a1', 'Mitre 123', city: 'Posadas'),
      items: items ??
          [OrderItem(cylinder: cylinder(), quantity: 1, subtotal: 1000)],
      total: total,
      paymentMethod: paymentMethod,
      status: status,
      createdAt: DateTime(2026, 10, 10, 18, 30),
    );

/// Carrito de verdad: el mock de CartService no guarda nada.
class FakeCart extends CartService {
  FakeCart() : super(tokenReader: () async => 'tok');

  /// Sin red: el carrito sembrado es el que "devolvió el back".
  @override
  Future<ApiResult<void>> refresh() async => const ApiResult.ok();

  /// Carga el carrito con los ítems y la dirección de [o], como los devolvería
  /// el back.
  @override
  Future<ApiResult<void>> add(String gasCylinderId, int quantity) async {
    final line = cart.lineFor(gasCylinderId);
    final qty = (line?.quantity ?? 0) + quantity;
    seed(
        cart: _withLine(gasCylinderId, qty, line?.type ?? 'Garrafa 10kg'),
        address: address);
    return const ApiResult.ok();
  }

  Cart _withLine(String id, int qty, String type) {
    final others = cart.items.where((l) => l.gasCylinderId != id);
    return Cart(
      cartId: 'c1',
      items: [
        ...others,
        CartLine(
          cartItemId: 'ci-$id',
          gasCylinderId: id,
          type: type,
          quantity: qty,
          savedUnitPrice: 1000,
          currentUnitPrice: 1000,
          priceDifference: 0,
          subtotal: 1000.0 * qty,
          available: true,
          hasEnoughStock: true,
        ),
      ],
    );
  }

  void seedOrder(Order o) => seed(cart: cartOf(o), address: o.address);
}

/// El carrito que devolvería el back por los ítems de [o].
Cart cartOf(Order o) => Cart(
      cartId: 'c1',
      items: [
        for (final i in o.items)
          CartLine(
            cartItemId: 'ci-${i.cylinder.id}',
            gasCylinderId: i.cylinder.id,
            type: i.cylinder.type,
            quantity: i.quantity,
            savedUnitPrice: i.cylinder.price,
            currentUnitPrice: i.cylinder.price,
            priceDifference: 0,
            subtotal: i.cylinder.price * i.quantity,
            available: true,
            hasEnoughStock: true,
          ),
      ],
      totalUnits: o.items.fold(0, (n, i) => n + i.quantity),
      total: o.items.fold(0.0, (n, i) => n + i.cylinder.price * i.quantity),
    );

/// Cotización como la devolvería `POST /orders/quote` por [qty] garrafas de
/// [unit] cada una (promoción por volumen ya aplicada) más los recargos.
QuoteOutcome backQuote({
  String id = 'g1',
  int qty = 2,
  double unit = 900,
  double paymentSurcharge = 0,
  double zoneSurcharge = 0,
  String? zoneName,
  String? paymentMethod,
  double? paymentSurchargePercentage,
  double? discountPercentage,
}) {
  final subtotal = unit * qty;
  final total = subtotal + zoneSurcharge + paymentSurcharge;
  return QuoteOutcome.ok(OrderQuote(
    lines: [
      QuoteLine(
          gasCylinderId: id,
          quantity: qty,
          unitPrice: unit,
          subtotal: subtotal,
          discountPercentage: discountPercentage)
    ],
    subtotal: subtotal,
    zoneSurcharge: zoneSurcharge,
    zoneName: zoneName,
    paymentSurcharge: paymentSurcharge,
    deposit: 0,
    total: total,
    balance: total,
    paymentMethod: paymentMethod,
    paymentSurchargePercentage: paymentSurchargePercentage,
  ));
}
