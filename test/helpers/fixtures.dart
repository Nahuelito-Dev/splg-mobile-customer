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
  double price = 1000,
  List<Discount>? discounts,
}) =>
    GasCylinder(
      id: id,
      type: 'Garrafa 10kg',
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
}) =>
    Order(
      id: id,
      address: address ?? addr('a1', 'Mitre 123', city: 'Posadas'),
      items: items ?? [OrderItem(cylinder: cylinder(), quantity: 1)],
      total: total,
      paymentMethod: PaymentMethod.cash,
      status: status,
      createdAt: DateTime(2026, 10, 10, 18, 30),
    );

/// Carrito de verdad: el mock de CartService no guarda nada.
class FakeCart extends CartService {}
