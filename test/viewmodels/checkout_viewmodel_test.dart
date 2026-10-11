import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/customer.dart';
import 'package:splg_lib/domain/order.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

Order _orderWithout(Address? address) => Order(
      id: '1',
      address: address,
      items: [],
      total: 0,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.pending,
      createdAt: DateTime(2026, 10, 10),
    );

Address _addr(String id, String street, {bool primary = false}) =>
    Address(addressId: id, streetName: street, primary: primary);

void main() {
  group('CheckoutViewModel Tests -', () {
    late MockCartService cart;
    late MockCustomerService customers;

    setUp(() {
      registerServices();
      cart = locator<CartService>() as MockCartService;
      customers = locator<CustomerService>() as MockCustomerService;
    });
    tearDown(() => locator.reset());

    Customer withAddresses(List<Address> a) => Customer(
          customerId: 'c',
          fullName: 'Cliente',
          email: 'c@c.com',
          phoneNumber: '1',
          blocked: false,
          addresses: a,
        );

    test('si el carrito no trae dirección usa la predeterminada del cliente',
        () async {
      final order = _orderWithout(null);
      when(cart.order).thenReturn(order);
      when(customers.customer).thenReturn(withAddresses([
        _addr('a', 'Calle 1'),
        _addr('b', 'Calle 2', primary: true),
      ]));

      final model = CheckoutViewModel()..initialize();
      await Future<void>.delayed(Duration.zero);

      expect(model.addressController.text, 'Calle 2');
      final saved = verify(cart.setOrder(captureAny)).captured.single as Order;
      expect(saved.address?.addressId, 'b');
    });

    test('sin predeterminada toma la primera; sin direcciones queda vacío', () {
      when(cart.order).thenReturn(_orderWithout(null));
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1')]));
      expect((CheckoutViewModel()..initialize()).addressController.text,
          'Calle 1');

      when(customers.customer).thenReturn(withAddresses([]));
      expect((CheckoutViewModel()..initialize()).addressController.text, '');
    });

    test('respeta la dirección que el carrito ya tiene', () {
      when(cart.order).thenReturn(_orderWithout(_addr('z', 'Calle Elegida')));
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));

      final model = CheckoutViewModel()..initialize();

      expect(model.addressController.text, 'Calle Elegida');
      verifyNever(cart.setOrder(any));
    });
  });
}
