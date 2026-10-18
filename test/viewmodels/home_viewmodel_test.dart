import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_cart_backend.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockCustomerService customers;
  late MockHistoryService history;
  late MockNavigationService nav;
  late FakeCartBackend backend;

  setUp(() {
    registerServices();
    // El carrito real contra un /cart simulado: HomeViewModel lo maneja ahí.
    backend = FakeCartBackend();
    locator.unregister<CartService>();
    locator.registerSingleton<CartService>(TestCart());
    customers = locator<CustomerService>() as MockCustomerService;
    history = locator<HistoryService>() as MockHistoryService;
    nav = locator<NavigationService>() as MockNavigationService;
    when(customers.customer).thenReturn(customerWith());
    when(customers.isUserLoggedIn).thenReturn(true);
    when(history.history).thenReturn(<Order>[]);
  });
  tearDown(() => locator.reset());

  test('suma y resta garrafas en el carrito del back', () async {
    final c = cylinder(price: 1000);
    final model = HomeViewModel();
    await model.addItem(c, 1);
    await model.addItem(c, 1);
    expect(model.getItemQuantity(c.id), 2);
    expect(model.itemCount, 2);
    expect(model.continueLabel, 'Continuar · 2 garrafas');
    await model.addItem(c, -1);
    expect(model.continueLabel, 'Continuar · 1 garrafa');
    await model.addItem(c, -1);
    expect(model.getItemQuantity(c.id), 0);
    expect(model.canPlaceOrder, isFalse);
    // Cada tap fue una llamada: agregar, agregar, bajar a 1 (PATCH), quitar.
    expect(backend.calls, [
      'POST cart/items',
      'POST cart/items',
      startsWith('PATCH cart/items/'),
      startsWith('DELETE cart/items/'),
    ]);
  });

  test('el botón no lleva precio: lo cotiza el back en la confirmación',
      () async {
    final c = cylinder(price: 1000, discounts: [
      Discount(quantity: 4, percentage: 20),
      Discount(quantity: 2, percentage: 10),
    ]);
    final model = HomeViewModel();
    for (var i = 0; i < 2; i++) {
      await model.addItem(c, 1);
    }
    expect(model.continueLabel, 'Continuar · 2 garrafas');
    expect(model.continueLabel, isNot(contains('\$')));
  });

  test('sin sesión agregar lleva al login y no toca el carrito', () async {
    when(customers.isUserLoggedIn).thenReturn(false);
    final model = HomeViewModel();
    await model.addItem(cylinder(), 1);
    verify(nav.navigateToLoginView()).called(1);
    expect(backend.calls, isEmpty);
    expect(model.itemCount, 0);
  });

  test('si el back rechaza agregar, lo muestra y no cambia el carrito',
      () async {
    final model = HomeViewModel();
    await model.addItem(cylinder(), 1);
    backend.failNext = const FakeReply(
        400, {'message': 'La cantidad no puede superar 999 unidades por ítem'});
    await model.addItem(cylinder(), 1);
    expect(model.getItemQuantity('g1'), 1);
    verify(locator<DialogService>().showDialog(
      title: 'No pudimos actualizar el carrito',
      description: 'La cantidad no puede superar 999 unidades por ítem',
      buttonTitle: 'Aceptar',
    )).called(1);
  });

  test('sin conexión no se da por hecho el cambio y se avisa', () async {
    final model = HomeViewModel();
    backend.failNext = const FakeReply.networkError();
    await model.addItem(cylinder(), 1);
    expect(model.itemCount, 0);
    verify(locator<DialogService>().showDialog(
      title: 'No pudimos actualizar el carrito',
      description: 'Sin conexión. Revisá tu internet.',
      buttonTitle: 'Aceptar',
    )).called(1);
  });

  test('al abrir trae el carrito que ya tenía en el back', () async {
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenAnswer((_) async => [cylinder()]);
    await TestCart().add('g1', 3);
    final model = HomeViewModel();
    await model.initialize();
    expect(model.itemCount, 3);
    expect(model.cartError, isNull);
    model.dispose();
  });

  test('la dirección de entrega es la predeterminada, o la primera', () {
    when(customers.customer).thenReturn(customerWith(
        [addr('a', 'Calle 1'), addr('b', 'Calle 2', primary: true)]));
    expect(HomeViewModel().deliveryLabel, 'Entregar en: Calle 2');

    when(customers.customer).thenReturn(customerWith([addr('a', 'Calle 1')]));
    expect(HomeViewModel().deliveryAddress?.addressId, 'a');

    when(customers.customer).thenReturn(customerWith());
    expect(HomeViewModel().deliveryLabel, 'Elegí tu dirección de entrega');
  });

  test('"Continuar" con sesión abre el carrito; sin sesión, el login',
      () async {
    final model = HomeViewModel();
    await model.addItem(cylinder(), 1);
    model.placeOrder();
    verify(nav.navigateToCartView()).called(1);

    when(customers.isUserLoggedIn).thenReturn(false);
    model.placeOrder();
    verify(nav.navigateToLoginView()).called(1);
  });

  test('sin garrafas elegidas no deja continuar', () {
    final model = HomeViewModel();
    model.placeOrder();
    verifyNever(nav.navigateToCartView());
  });

  test('el pedido en curso se informa con su estado', () {
    when(history.history).thenReturn([
      order(id: 'x', status: OrderStatus.delivered),
      order(id: 'pedido-123456', status: OrderStatus.outForDelivery),
    ]);
    final model = HomeViewModel();
    expect(model.hasActiveOrder, isTrue);
    expect(model.activeOrderShortCode, '123456');
    expect(model.activeOrderStatusLabel, 'Tu pedido está en camino');
  });

  test('sin pedidos en curso no hay banner', () {
    when(history.history).thenReturn([order(status: OrderStatus.delivered)]);
    expect(HomeViewModel().hasActiveOrder, isFalse);
  });

  test('elegir una dirección la deja en el carrito', () async {
    final sheets = locator<BottomSheetService>() as MockBottomSheetService;
    final chosen = addr('z', 'Elegida');
    when(customers.customer).thenReturn(customerWith([chosen]));
    when(sheets.showCustomSheet(
      variant: anyNamed('variant'),
      title: anyNamed('title'),
      data: anyNamed('data'),
    )).thenAnswer((_) async => SheetResponse(confirmed: true, data: chosen));
    final model = HomeViewModel();
    await model.addItem(cylinder(), 1);

    await model.chooseAddress();

    expect(model.deliveryAddress?.addressId, 'z');
    expect(locator<CartService>().address?.addressId, 'z');
  });

  test('pedido con item de otra garrafa suma por separado', () async {
    final a = cylinder(id: 'g1');
    final b = cylinder(id: 'g2', price: 500);
    final model = HomeViewModel();
    await model.addItem(a, 1);
    await model.addItem(b, 1);
    await model.addItem(b, 1);
    expect(model.itemCount, 3);
    expect(
        locator<CartService>().order!.items.map((OrderItem i) => i.cylinder.id),
        containsAll(['g1', 'g2']));
  });

  // ─── Dirección elegida: alta, borrado y edición ───
  void stubForm(Object? result) => when(nav.navigateTo<dynamic>(
        Routes.addressFormView,
        arguments: anyNamed('arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).thenAnswer((_) async => result);

  Future<HomeViewModel> homeWithChosen(String id) async {
    final sheets = locator<BottomSheetService>() as MockBottomSheetService;
    final all = customers.customer.addresses;
    when(sheets.showCustomSheet(
      variant: anyNamed('variant'),
      title: anyNamed('title'),
      data: anyNamed('data'),
    )).thenAnswer((_) async => SheetResponse(
        confirmed: true, data: all.firstWhere((a) => a.addressId == id)));
    final model = HomeViewModel();
    await model.addItem(cylinder(), 1);
    await model.chooseAddress();
    return model;
  }

  test('el alta elige la dirección creada, no la predeterminada', () async {
    final a = addr('a', 'Calle A', primary: true);
    final b = addr('b', 'Calle B');
    final c = addr('c', 'Calle C');
    when(customers.customer).thenReturn(customerWith([a, b, c]));
    final model = await homeWithChosen('b');
    stubForm(c);

    await model.addAddress();

    expect(model.deliveryAddress?.addressId, 'c');
    expect(locator<CartService>().address?.addressId, 'c');
  });

  test('cancelar el formulario no pisa la dirección elegida', () async {
    final a = addr('a', 'Calle A', primary: true);
    final b = addr('b', 'Calle B');
    when(customers.customer).thenReturn(customerWith([a, b]));
    final model = await homeWithChosen('b');
    stubForm(null);

    await model.addAddress();

    expect(model.deliveryAddress?.addressId, 'b');
    expect(locator<CartService>().address?.addressId, 'b');
  });

  test('editar el formulario (devuelve true) tampoco cambia la elegida',
      () async {
    final a = addr('a', 'Calle A', primary: true);
    final b = addr('b', 'Calle B');
    when(customers.customer).thenReturn(customerWith([a, b]));
    final model = await homeWithChosen('b');
    stubForm(true);

    await model.addAddress();

    expect(model.deliveryAddress?.addressId, 'b');
  });

  test('si se borra la dirección elegida vuelve a la predeterminada con aviso',
      () async {
    final a = addr('a', 'Calle A', primary: true);
    final b = addr('b', 'Calle B');
    when(customers.customer).thenReturn(customerWith([a, b]));
    final model = await homeWithChosen('b');

    when(customers.customer).thenReturn(customerWith([a]));
    model.reconcileAddress();

    expect(model.deliveryAddress?.addressId, 'a');
    expect(locator<CartService>().address?.addressId, 'a');
    expect(model.addressNotice, contains('ya no existe'));
  });

  test('si se borran todas, el Inicio y el carrito quedan sin dirección',
      () async {
    final b = addr('b', 'Calle B');
    when(customers.customer).thenReturn(customerWith([b]));
    final model = await homeWithChosen('b');

    when(customers.customer).thenReturn(customerWith([]));
    model.reconcileAddress();

    expect(model.deliveryAddress, isNull);
    expect(locator<CartService>().address, isNull);
    expect(model.deliveryLabel, 'Elegí tu dirección de entrega');
  });

  test('si se edita la dirección elegida, píldora y carrito toman los datos',
      () async {
    final b = addr('b', 'Calle B');
    when(customers.customer).thenReturn(customerWith([b]));
    final model = await homeWithChosen('b');

    when(customers.customer).thenReturn(customerWith([addr('b', 'Calle B 2')]));
    model.reconcileAddress();

    expect(model.deliveryLabel, 'Entregar en: Calle B 2');
    expect(locator<CartService>().address?.streetName, 'Calle B 2');
    expect(model.addressNotice, isNull);
  });

  // ─── Catálogo ───
  test('un error del catálogo queda como error y reloadCatalog lo recupera',
      () async {
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenThrow(Exception('sin red'));
    final model = HomeViewModel();
    await model.initialize();
    expect(model.loadError, isNotNull);
    expect(model.cylinders, isEmpty);

    when(gas.getGasCylinders()).thenAnswer((_) async => [cylinder()]);
    await model.reloadCatalog();
    expect(model.loadError, isNull);
    expect(model.cylinders, hasLength(1));
    model.dispose();
  });
}
