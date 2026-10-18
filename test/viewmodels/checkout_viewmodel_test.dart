import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/customer.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/bottom_sheets/address_list/address_list_sheet_model.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
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

GasCylinder _cyl() => GasCylinder(
    id: 'g1',
    type: 'Garrafa 10kg',
    weight: '10',
    price: 1000,
    active: true,
    description: '');

/// Abre el checkout y espera la cotización del back (sin ella no se confirma).
Future<CheckoutViewModel> _ready(MockHistoryService history) async {
  CheckoutViewModel.quoteDebounce = Duration.zero;
  addTearDown(() =>
      CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 400));
  when(history.quoteOrder(any,
          timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')))
      .thenAnswer((_) async => backQuote(unit: 1000, qty: 1));
  final model = CheckoutViewModel()..initialize();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return model;
}

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
      when(cart.address).thenReturn(null);
      when(customers.customer).thenReturn(withAddresses([
        _addr('a', 'Calle 1'),
        _addr('b', 'Calle 2', primary: true),
      ]));

      final model = CheckoutViewModel()..initialize();
      await Future<void>.delayed(Duration.zero);

      expect(model.addressController.text, 'Calle 2');
      final saved =
          verify(cart.setAddress(captureAny)).captured.single as Address;
      expect(saved.addressId, 'b');
    });

    test('sin predeterminada toma la primera; sin direcciones queda vacío', () {
      when(cart.address).thenReturn(null);
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1')]));
      expect((CheckoutViewModel()..initialize()).addressController.text,
          'Calle 1');

      when(customers.customer).thenReturn(withAddresses([]));
      expect((CheckoutViewModel()..initialize()).addressController.text, '');
    });

    test('respeta la dirección que el carrito ya tiene', () {
      when(cart.address).thenReturn(_addr('z', 'Calle Elegida'));
      when(customers.customer).thenReturn(withAddresses(
          [_addr('a', 'Calle 1', primary: true), _addr('z', 'Calle Elegida')]));

      final model = CheckoutViewModel()..initialize();

      expect(model.addressController.text, 'Calle Elegida');
      verifyNever(cart.setAddress(any));
    });

    test('si la dirección del carrito se borró vuelve a la predeterminada',
        () async {
      when(cart.address).thenReturn(_addr('z', 'Calle Borrada'));
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));

      final model = CheckoutViewModel()..initialize();
      await Future<void>.delayed(Duration.zero);

      expect(model.addressController.text, 'Calle 1');
      final saved =
          verify(cart.setAddress(captureAny)).captured.single as Address;
      expect(saved.addressId, 'a');
    });

    test('si la dirección del carrito se editó toma los datos nuevos',
        () async {
      when(cart.address).thenReturn(_addr('a', 'Calle Vieja'));
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle Nueva')]));

      final model = CheckoutViewModel()..initialize();
      await Future<void>.delayed(Duration.zero);

      expect(model.addressController.text, 'Calle Nueva');
      final saved =
          verify(cart.setAddress(captureAny)).captured.single as Address;
      expect(saved.streetName, 'Calle Nueva');
    });

    Future<void> stubForm(Object? result) async {
      final nav = locator<NavigationService>() as MockNavigationService;
      when(nav.navigateTo<dynamic>(
        Routes.addressFormView,
        arguments: anyNamed('arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).thenAnswer((_) async => result);
    }

    test('el alta desde el checkout elige la dirección creada, no la primaria',
        () async {
      when(cart.address).thenReturn(_addr('b', 'Calle B'));
      final c = _addr('c', 'Calle C');
      when(customers.customer).thenReturn(withAddresses(
          [_addr('a', 'Calle A', primary: true), _addr('b', 'Calle B'), c]));
      await stubForm(c);
      final sheets = locator<BottomSheetService>() as MockBottomSheetService;
      when(sheets.showCustomSheet(
        variant: anyNamed('variant'),
        title: anyNamed('title'),
        data: anyNamed('data'),
      )).thenAnswer((_) async =>
          SheetResponse(confirmed: true, data: AddressListSheetModel.addNew));

      final model = CheckoutViewModel()..initialize();
      await model.showAddressList();

      expect(model.addressController.text, 'Calle C');
      final saved =
          verify(cart.setAddress(captureAny)).captured.last as Address;
      expect(saved.addressId, 'c');
    });

    test('cancelar el formulario no cambia la dirección elegida', () async {
      when(cart.address).thenReturn(_addr('b', 'Calle B'));
      when(customers.customer).thenReturn(withAddresses(
          [_addr('a', 'Calle A', primary: true), _addr('b', 'Calle B')]));
      await stubForm(null);
      final sheets = locator<BottomSheetService>() as MockBottomSheetService;
      when(sheets.showCustomSheet(
        variant: anyNamed('variant'),
        title: anyNamed('title'),
        data: anyNamed('data'),
      )).thenAnswer((_) async =>
          SheetResponse(confirmed: true, data: AddressListSheetModel.addNew));

      final model = CheckoutViewModel()..initialize();
      await model.showAddressList();

      expect(model.addressController.text, 'Calle B');
      verifyNever(cart.setAddress(any));
    });

    Order withItems(Address? a) => _orderWithout(a).copyWith(
        items: [OrderItem(cylinder: _cyl(), quantity: 1)], total: 1000);

    test('confirmar con la dirección borrada no manda el pedido', () async {
      final order = withItems(_addr('z', 'Calle Borrada'));
      when(cart.order).thenReturn(order);
      when(cart.address).thenReturn(order.address);
      when(customers.isUserLoggedIn).thenReturn(true);
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));
      final history = locator<HistoryService>() as MockHistoryService;

      final model = await _ready(history);
      await model.confirmOrder();

      verifyNever(history.createOrder(any,
          timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')));
      verify(locator<DialogService>().showDialog(
        title: 'Dirección no disponible',
        description: anyNamed('description'),
        buttonTitle: 'Aceptar',
      )).called(1);
    });

    test('tras crear el pedido abre el seguimiento del recién creado',
        () async {
      final order = withItems(_addr('a', 'Calle 1', primary: true));
      when(cart.order).thenReturn(order);
      when(cart.address).thenReturn(order.address);
      when(customers.isUserLoggedIn).thenReturn(true);
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));
      final history = locator<HistoryService>() as MockHistoryService;
      // El historial todavía trae un pedido viejo primero.
      when(history.history)
          .thenReturn([_orderWithout(null).copyWith(id: 'viejo')]);
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart')))
          .thenAnswer((_) async => CreateOrderResult(
              success: true, order: _orderWithout(null).copyWith(id: 'nuevo')));
      final nav = locator<NavigationService>() as MockNavigationService;

      final model = await _ready(history);
      await model.confirmOrder();

      verify(nav.replaceWith<dynamic>(
        Routes.orderTrackingView,
        arguments: argThat(
            isA<OrderTrackingViewArguments>()
                .having((a) => a.orderId, 'orderId', 'nuevo'),
            named: 'arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).called(1);
    });

    test(
        'el pedido sale desde el carrito del back: no borra ítems, sólo lo '
        'vuelve a pedir', () async {
      final order = withItems(_addr('a', 'Calle 1', primary: true));
      when(cart.order).thenReturn(order);
      when(cart.address).thenReturn(order.address);
      when(customers.isUserLoggedIn).thenReturn(true);
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));
      final history = locator<HistoryService>() as MockHistoryService;
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart')))
          .thenAnswer((_) async => CreateOrderResult(
              success: true, order: _orderWithout(null).copyWith(id: 'nuevo')));

      final model = await _ready(history);
      await model.confirmOrder();

      verify(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'), fromCart: true))
          .called(1);
      verify(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'), fromCart: true))
          .called(greaterThan(0));
      verify(cart.refresh()).called(1);
      verifyNever(cart.remove(any));
      verifyNever(cart.clear());
    });

    test('si el pedido falla el carrito queda y, si está vacío, lleva a él',
        () async {
      final order = withItems(_addr('a', 'Calle 1', primary: true));
      when(cart.order).thenReturn(order);
      when(cart.address).thenReturn(order.address);
      when(cart.cart).thenReturn(Cart.empty);
      when(customers.isUserLoggedIn).thenReturn(true);
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));
      final history = locator<HistoryService>() as MockHistoryService;
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart')))
          .thenAnswer((_) async => const CreateOrderResult(
                success: false,
                message: 'El carrito está vacío',
                retryable: false,
              ));
      final nav = locator<NavigationService>() as MockNavigationService;

      final model = await _ready(history);
      await model.confirmOrder();

      verifyNever(cart.remove(any));
      verifyNever(cart.clear());
      verify(nav.navigateToCartView()).called(1);
    });

    test('si el back rechaza el pedido, muestra su mensaje (no el de conexión)',
        () async {
      final order = withItems(_addr('a', 'Calle 1', primary: true));
      when(cart.order).thenReturn(order);
      when(cart.address).thenReturn(order.address);
      when(cart.cart).thenReturn(Cart.empty);
      when(customers.isUserLoggedIn).thenReturn(true);
      when(customers.customer)
          .thenReturn(withAddresses([_addr('a', 'Calle 1', primary: true)]));
      final history = locator<HistoryService>() as MockHistoryService;
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart')))
          .thenAnswer((_) async => const CreateOrderResult(
                success: false,
                message: 'La dirección está fuera de la zona de cobertura',
                retryable: false,
              ));

      final model = await _ready(history);
      await model.confirmOrder();

      verify(locator<DialogService>().showDialog(
        title: 'No pudimos crear tu pedido',
        description: 'La dirección está fuera de la zona de cobertura',
      )).called(1);
    });
  });
}
