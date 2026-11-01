import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_customer/services/photo_service.dart';
import 'package:splg_customer/services/profile_photo_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/ui/views/about/about_view.dart';
import 'package:splg_customer/ui/views/address_form/address_form_view.dart';
import 'package:splg_customer/ui/views/addresses/addresses_view.dart';
import 'package:splg_customer/ui/views/cancel_order/cancel_order_view.dart';
import 'package:splg_customer/ui/views/change_password/change_password_view.dart';
import 'package:splg_customer/ui/views/cart/cart_view.dart';
import 'package:splg_customer/ui/views/checkout/checkout_view.dart';
import 'package:splg_customer/ui/views/claim_detail/claim_detail_view.dart';
import 'package:splg_customer/ui/views/claims/claims_view.dart';
import 'package:splg_customer/ui/views/edit_order/edit_order_view.dart';
import 'package:splg_customer/ui/views/edit_order/edit_order_viewmodel.dart';
import 'package:splg_customer/ui/views/edit_profile/edit_profile_view.dart';
import 'package:splg_customer/ui/views/help/help_view.dart';
import 'package:splg_customer/ui/views/home/widgets/cylinder_detail_sheet.dart';
import 'package:splg_customer/domain/payment_term.dart';
import 'package:splg_customer/ui/views/home/home_view.dart';
import 'package:splg_customer/ui/views/login/login_view.dart';
import 'package:splg_customer/ui/views/notifications/notifications_view.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_view.dart';
import 'package:splg_customer/ui/views/orders/orders_view.dart';
import 'package:splg_customer/ui/views/personal_info/personal_info_view.dart';
import 'package:splg_customer/ui/views/profile/profile_view.dart';
import 'package:splg_customer/ui/views/recover_password/recover_password_view.dart';
import 'package:splg_customer/ui/views/signup/signup_view.dart';
import 'package:splg_customer/ui/views/signup_done/signup_done_view.dart';
import 'package:splg_customer/ui/views/welcome/welcome_view.dart';
import 'package:splg_customer/ui/widgets/app_drawer/app_drawer.dart';
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'package:splg_customer/ui/views/home/widgets/home_map.dart';
import 'package:splg_customer/services/session_service.dart';
import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:splg_customer/ui/views/public_catalog/public_catalog_view.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

/// Una prueba de widget en una pantalla de teléfono (393x852, 1x).
void phoneTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await body(t);
  });
}

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  late MockCustomerService customers;
  late MockHistoryService history;
  late MockNavigationService nav;
  late MockClaimService claims;

  setUpAll(() => initializeDateFormatting('es_AR', null));
  setUp(() => HomeMap.placeholder = true);
  tearDown(() => HomeMap.placeholder = false);

  setUp(() {
    registerServices();
    customers = locator<CustomerService>() as MockCustomerService;
    history = locator<HistoryService>() as MockHistoryService;
    nav = locator<NavigationService>() as MockNavigationService;
    claims = locator<ClaimService>() as MockClaimService;
    when(customers.customer).thenReturn(customerWith([
      addr('a1', 'Buenos Aires 4114', primary: true, city: 'Posadas'),
      addr('a2', 'Mitre 123', city: 'Posadas'),
    ]));
    when(customers.isUserLoggedIn).thenReturn(true);
    when(history.history).thenReturn(<Order>[]);
    when((locator<PhotoService>() as MockPhotoService).claimPhotoLink(any))
        .thenAnswer((_) async => const ApiResult.ok(null));
  });

  void stubPage(List<Order> orders) => when(history.fetchOrdersPage(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async =>
          OrdersPage(orders: orders, total: orders.length, offset: 0));

  tearDown(() => locator.reset());

  group('Acceso', () {
    phoneTest('bienvenida: "Comenzar" va al login', (t) async {
      await t.pumpWidget(app(const WelcomeView()));
      expect(find.textContaining('sin salir de casa'), findsOneWidget);
      await t.tap(find.text('Comenzar'));
      verify(nav.navigateToLoginView()).called(1);
    });

    phoneTest('bienvenida: "Ver garrafas y precios" abre el catálogo público',
        (t) async {
      await t.pumpWidget(app(const WelcomeView()));
      await t.tap(find.text('Ver garrafas y precios'));
      verify(nav.navigateToPublicCatalogView()).called(1);
    });

    phoneTest('catálogo público: se ve sin sesión y "Pedir" va al login',
        (t) async {
      when(customers.isUserLoggedIn).thenReturn(false);
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getPublicCatalog()).thenAnswer((_) async => [
            cylinder(price: 14900),
            cylinder(id: 'g2', type: 'Garrafa 15kg', price: 21500),
          ]);
      when(gas.outOfStock).thenReturn({'g2'});
      await t.pumpWidget(app(const PublicCatalogView()));
      await settle(t);
      expect(find.text('Garrafa 10kg'), findsOneWidget);
      expect(find.text('Sin stock'), findsOneWidget);
      expect(find.text('Iniciar sesión o registrarme'), findsOneWidget);
      await t.tap(find.byTooltip('Agregar uno').first);
      await settle(t);
      expect(find.text('Pedir · 1 garrafa'), findsOneWidget);
      await t.tap(find.byKey(const Key('public-catalog-action')));
      verify(gas.savePendingSelection({'g1': 1})).called(1);
      verify(nav.navigateToLoginView()).called(1);
    });

    phoneTest('login: campos, recuperar y registrarse', (t) async {
      await t.pumpWidget(app(const LoginView()));
      expect(find.text('¡Hola!'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      await t.tap(find.text('Registrarse'));
      verify(nav.navigateToSignupView()).called(1);
      await t.tap(find.text('¿Olvidaste tu contraseña?'));
      verify(nav.navigateToRecoverPasswordView(email: null)).called(1);
    });

    phoneTest('login: sin datos muestra el error', (t) async {
      await t.pumpWidget(app(const LoginView()));
      await t.tap(find.text('Continuar'));
      await settle(t);
      expect(find.text('Ingresá tu email y contraseña.'), findsOneWidget);
    });

    phoneTest('registro: paso 1 con errores y paso 2', (t) async {
      await t.pumpWidget(app(const SignupView()));
      expect(find.text('1. Tus datos'), findsOneWidget);
      await t.tap(find.text('Siguiente'));
      await settle(t);
      expect(find.text('Ingresá tu nombre y apellido.'), findsOneWidget);
      expect(find.text('Ingresá un teléfono válido.'), findsOneWidget);

      await t.enterText(find.byKey(const Key('signup-name')), 'QA Test');
      await t.enterText(find.byKey(const Key('signup-phone')), '3815550999');
      await t.tap(find.text('Siguiente'));
      await settle(t);
      expect(find.text('2. Tu cuenta'), findsOneWidget);
      expect(find.text('Aceptar Términos y condiciones'), findsOneWidget);
      await t.tap(find.text('Siguiente'));
      await settle(t);
      expect(find.byKey(const Key('signup-error')), findsOneWidget);
    });

    phoneTest('recuperar contraseña pide un email válido', (t) async {
      await t.pumpWidget(app(const RecoverPasswordView()));
      expect(find.text('RECUPERAR CONTRASEÑA'), findsOneWidget);
      await t.tap(find.text('Enviar'));
      await settle(t);
      expect(find.text('Ingresá un email válido.'), findsOneWidget);
    });

    phoneTest('registro completado', (t) async {
      await t.pumpWidget(app(const SignupDoneView()));
      expect(find.text('¡Registro completado!'), findsOneWidget);
      await t.tap(find.text('Ir al inicio'));
      verify(nav.clearStackAndShow(Routes.homeView)).called(1);
    });
  });

  group('Menú lateral', () {
    phoneTest('lista todo y cada ítem navega', (t) async {
      await t.pumpWidget(app(const Scaffold(drawer: AppDrawer())));
      t.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await t.pumpAndSettle();
      for (final item in [
        'Mi perfil',
        'Mis pedidos',
        'Mis direcciones',
        'Mis reclamos',
        'Notificaciones',
        'Ayuda',
        'Términos y condiciones',
        'Políticas de privacidad',
        'Acerca de SPLG',
        'Cerrar sesión',
      ]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      expect(t.getTopLeft(find.text('Mis pedidos')).dy,
          lessThan(t.getTopLeft(find.text('Mi perfil')).dy));
      await t.tap(find.text('Mis pedidos'));
      await t.pumpAndSettle();
      verify(nav.navigateToOrdersView()).called(1);
    });

    phoneTest('cerrar sesión pide confirmación y no cierra si cancelás',
        (t) async {
      await t.pumpWidget(app(const Scaffold(drawer: AppDrawer())));
      t.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await t.pumpAndSettle();
      await t.tap(find.text('Cerrar sesión'));
      await t.pumpAndSettle();
      expect(find.text('¿Querés cerrar sesión?'), findsOneWidget);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      verifyNever(customers.signOut());
    });

    phoneTest('cerrar sesión confirmado cierra y va al login', (t) async {
      await t.pumpWidget(app(const Scaffold(drawer: AppDrawer())));
      t.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await t.pumpAndSettle();
      await t.tap(find.text('Cerrar sesión'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cerrar sesión').last);
      await t.pumpAndSettle();
      verify(locator<SessionService>().logout()).called(1);
    });
  });

  group('Inicio', () {
    setUp(() {
      locator.unregister<CartService>();
      locator.registerSingleton<CartService>(FakeCart());
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenAnswer((_) async => [
            cylinder(price: 14900, discounts: [
              Discount(quantity: 2, percentage: 5),
              Discount(quantity: 4, percentage: 12),
            ]),
            cylinder(id: 'g2', price: 8500),
          ]);
    });

    phoneTest('mapa, botones flotantes y hoja inferior como Tutu', (t) async {
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.byKey(const Key('home-map-placeholder')), findsOneWidget);
      expect(find.byTooltip('Abrir menú'), findsOneWidget);
      expect(find.byTooltip('Mi ubicación'), findsOneWidget);
      expect(find.text('Entregar en: Buenos Aires 4114'), findsOneWidget);
      expect(find.text('¿Qué necesitás?'), findsOneWidget);
      expect(find.byTooltip('Agregar dirección'), findsOneWidget);
      // El catálogo no se muestra hasta abrirlo; sin barra inferior.
      expect(find.text('Elegí tus garrafas'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      // Menú arriba a la izquierda, "Mi ubicación" abajo a la derecha.
      final menu = t.getCenter(find.byTooltip('Abrir menú'));
      final locate = t.getCenter(find.byTooltip('Mi ubicación'));
      expect(menu.dx, lessThan(100));
      expect(menu.dy, lessThan(120));
      expect(locate.dx, greaterThan(300));
      expect(locate.dy, greaterThan(menu.dy));
    });

    phoneTest('el mapa se centra y marca la dirección elegida', (t) async {
      when(customers.customer).thenReturn(customerWith([
        Address(
            addressId: 'a1',
            streetName: 'Buenos Aires 4114',
            primary: true,
            latitude: '-27.3671',
            longitude: '-55.8961'),
      ]));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      final map = t.widget<HomeMap>(find.byType(HomeMap));
      expect(map.delivery!.latitude, closeTo(-27.3671, 1e-6));
      expect(map.delivery!.longitude, closeTo(-55.8961, 1e-6));
    });

    phoneTest('una dirección en 0,0 no se marca', (t) async {
      when(customers.customer).thenReturn(customerWith([
        Address(
            addressId: 'a1',
            streetName: 'X',
            primary: true,
            latitude: '0',
            longitude: '0'),
      ]));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(t.widget<HomeMap>(find.byType(HomeMap)).delivery, isNull);
    });

    phoneTest('catálogo con promociones y total en la hoja', (t) async {
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byKey(const Key('home-catalog-field')));
      await t.pumpAndSettle();
      expect(find.text('Elegí tus garrafas'), findsWidgets);
      expect(find.text('−5% x2'), findsOneWidget);

      await t.tap(find.byTooltip('Agregar uno').first);
      await t.tap(find.byTooltip('Agregar uno').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Continuar · 2 garrafas'), findsWidgets);
      await t.tap(find.textContaining('Continuar ·').last);
      await t.pumpAndSettle();
      verify(nav.navigateToCartView()).called(1);
    });

    phoneTest('la píldora abre las direcciones y el + el alta', (t) async {
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.text('Entregar en: Buenos Aires 4114'));
      await settle(t);
      verify(locator<BottomSheetService>().showCustomSheet(
        variant: anyNamed('variant'),
        title: anyNamed('title'),
        data: anyNamed('data'),
      )).called(1);
      await t.tap(find.byTooltip('Agregar dirección'));
      await settle(t);
      verify(nav.navigateToAddressFormView()).called(1);
    });

    phoneTest('Mi ubicación sólo pide la posición al tocarlo', (t) async {
      final location = locator<LocationService>() as MockLocationService;
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      verifyNever(location.getCurrentPosition());
      when(location.getCurrentPosition()).thenAnswer((_) async => Position(
            latitude: -27.36,
            longitude: -55.89,
            timestamp: DateTime(2026),
            accuracy: 1,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ));
      await t.tap(find.byTooltip('Mi ubicación'));
      await settle(t);
      verify(location.getCurrentPosition()).called(1);
      final map = t.widget<HomeMap>(find.byType(HomeMap));
      expect(map.showUserLocation, isTrue);
      expect(map.user!.latitude, closeTo(-27.36, 1e-6));
    });

    phoneTest('Mi ubicación sin permiso no rompe ni habilita el punto',
        (t) async {
      final location = locator<LocationService>() as MockLocationService;
      when(location.getCurrentPosition()).thenThrow(
          const LocationUnavailableException(PermissionOutcome.denied));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byTooltip('Mi ubicación'));
      await settle(t);
      expect(t.widget<HomeMap>(find.byType(HomeMap)).showUserLocation, isFalse);
    });

    phoneTest('con el GPS apagado avisa y ofrece ir a Ajustes', (t) async {
      final location = locator<LocationService>() as MockLocationService;
      when(location.getCurrentPosition()).thenThrow(
          const LocationUnavailableException(PermissionOutcome.granted,
              serviceDisabled: true));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byTooltip('Mi ubicación'));
      await settle(t);
      expect(find.byKey(const Key('home-location-notice')), findsOneWidget);
      expect(find.textContaining('Activá la ubicación'), findsOneWidget);
      await t.tap(find.text('Ajustes'));
      verify(location.openLocationSettings()).called(1);
      await t.tap(find.byTooltip('Cerrar aviso'));
      await settle(t);
      expect(find.byKey(const Key('home-location-notice')), findsNothing);
    });

    phoneTest('Mi ubicación: un segundo toque mientras busca no repite',
        (t) async {
      final location = locator<LocationService>() as MockLocationService;
      final gate = Completer<Position>();
      when(location.getCurrentPosition()).thenAnswer((_) => gate.future);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byTooltip('Mi ubicación'));
      await t.tap(find.byTooltip('Mi ubicación'));
      await settle(t);
      verify(location.getCurrentPosition()).called(1);
      gate.completeError(Exception('x'));
      await settle(t);
    });

    phoneTest('Mi ubicación: si no responde en 15 s avisa', (t) async {
      final location = locator<LocationService>() as MockLocationService;
      when(location.getCurrentPosition())
          .thenAnswer((_) => Completer<Position>().future);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byTooltip('Mi ubicación'));
      await t.pump(HomeViewModel.locateTimeout + const Duration(seconds: 1));
      expect(find.textContaining('No pudimos ubicarte'), findsOneWidget);
    });

    phoneTest('si el catálogo falló, abrir "¿Qué necesitás?" reintenta',
        (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenThrow(Exception('x'));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      when(gas.getGasCylinders()).thenAnswer((_) async => [cylinder()]);
      await t.tap(find.byKey(const Key('home-catalog-field')));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(SplgProductCard),
              matching: find.text('Garrafa 10kg')),
          findsOneWidget);
      expect(find.text('No pudimos cargar'), findsNothing);
    });

    phoneTest(
        'la tira del inicio muestra foto, nombre y precio; tocar suma y abre',
        (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenAnswer((_) async => [
            cylinder(price: 14900),
            cylinder(id: 'g2', type: 'Garrafa 15kg', price: 21500),
          ]);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      final strip = find.byKey(const Key('home-featured-strip'));
      expect(strip, findsOneWidget);
      expect(find.descendant(of: strip, matching: find.text('Garrafa 15kg')),
          findsOneWidget);
      expect(
          find.descendant(of: strip, matching: find.textContaining('21.500')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('home-featured-g2')));
      await t.pumpAndSettle();
      expect(find.text('Elegí tus garrafas'), findsWidgets);
      expect(find.textContaining('Continuar · 1 garrafa'), findsWidgets);
    });

    phoneTest('sin catálogo no hay tira', (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenThrow(Exception('x'));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.byKey(const Key('home-featured-strip')), findsNothing);
    });

    testWidgets('la tira entra en un Android de 1080x2400 sin desbordar',
        (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenAnswer(
          (_) async => [cylinder(), cylinder(id: 'g2'), cylinder(id: 'g3')]);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.byKey(const Key('home-featured-strip')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    phoneTest('el inicio tiene un solo botón de menú y no el de pedidos',
        (t) async {
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.byTooltip('Abrir menú'), findsOneWidget);
      expect(find.byTooltip('Ir a mis pedidos'), findsNothing);
    });

    phoneTest('el menú abre el cajón', (t) async {
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byTooltip('Abrir menú'));
      await t.pumpAndSettle();
      expect(find.text('Mis pedidos'), findsOneWidget);
    });

    phoneTest('con un pedido en curso muestra el banner', (t) async {
      when(history.history)
          .thenReturn([order(id: 'abc123456', status: OrderStatus.pending)]);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.text('Pedido en curso #123456'), findsOneWidget);
      expect(find.text('Buscando repartidor'), findsOneWidget);
    });

    phoneTest('si no carga el catálogo ofrece reintentar', (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenThrow(Exception('x'));
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byKey(const Key('home-catalog-field')));
      await t.pumpAndSettle();
      expect(find.text('No pudimos cargar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('Mis pedidos', () {
    phoneTest('lista con estado, total y forma de pago', (t) async {
      final p2 = order(id: 'p2', status: OrderStatus.delivered, total: 5000);
      stubPage([order(id: 'p1', status: OrderStatus.pending), p2]);
      await t.pumpWidget(app(const OrdersView()));
      await settle(t);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('ENTREGADO'), findsOneWidget);
      expect(find.textContaining('Efectivo'), findsWidgets);
      await t.tap(find.byKey(const Key('order-p2')));
      verify(nav.navigateTo<dynamic>(
        Routes.orderDetailView,
        arguments: OrderDetailViewArguments(orderId: 'p2', order: p2),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).called(1);
    });

    phoneTest('vacío', (t) async {
      stubPage(const []);
      await t.pumpWidget(app(const OrdersView()));
      await settle(t);
      expect(find.text('¡Nada por aquí!'), findsOneWidget);
      expect(find.text('Todavía no hiciste ningún pedido.'), findsOneWidget);
    });

    phoneTest('detalle de un pedido pendiente: cancelar y modificar',
        (t) async {
      when(history.fetchOrderDetail('o1')).thenAnswer(
          (_) async => OrderDetail(order(status: OrderStatus.pending), null));
      await t.pumpWidget(app(const OrderDetailView(orderId: 'o1')));
      await settle(t);
      expect(find.byKey(const Key('detail-total')), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsOneWidget);
      expect(find.text('Modificar pedido'), findsOneWidget);
      expect(find.text('Calificar al repartidor'), findsNothing);
    });

    phoneTest(
        'detalle: el total se explica con los renglones y los recargos de zona '
        'y de medio de pago', (t) async {
      when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
          order(total: 17380, paymentMethod: PaymentMethod.online),
          const OrderBreakdown(
              total: 17380,
              itemsSubtotal: 14900,
              zoneSurcharge: 900,
              zoneName: 'Villa Cabello',
              paymentSurchargeAmount: 1580,
              paymentSurchargePercentage: 10)));
      await t.pumpWidget(app(const OrderDetailView(orderId: 'o1')));
      await settle(t);
      expect(find.text('Recargo por zona'), findsOneWidget);
      expect(find.text('\$900'), findsOneWidget);
      expect(find.text('Recargo por transferencia (10 %)'), findsOneWidget);
      expect(find.text('\$1.580'), findsOneWidget);
    });

    phoneTest('detalle por transferencia: muestra el monto exacto a transferir',
        (t) async {
      when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
          order(total: 19350, paymentMethod: PaymentMethod.online),
          const OrderBreakdown(
              total: 19350,
              itemsSubtotal: 18000,
              paymentStatus: 'pending',
              paymentSurchargeAmount: 1350,
              paymentSurchargePercentage: 7.5)));
      await t.pumpWidget(app(const OrderDetailView(orderId: 'o1')));
      await settle(t);
      expect(find.text('Recargo por transferencia (7,5 %)'), findsOneWidget);
      expect(find.byKey(const Key('transfer-amount')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('transfer-amount')),
              matching: find.text('\$19.350')),
          findsOneWidget);
    });

    phoneTest('detalle sin recargos no muestra renglones de más', (t) async {
      when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
          order(), const OrderBreakdown(total: 1000, itemsSubtotal: 1000)));
      await t.pumpWidget(app(const OrderDetailView(orderId: 'o1')));
      await settle(t);
      expect(find.text('Recargo por zona'), findsNothing);
      expect(find.textContaining('Recargo por'), findsNothing);
    });

    phoneTest('detalle de un pedido entregado: calificar, reclamar, repetir',
        (t) async {
      when(history.fetchOrderDetail('o1')).thenAnswer(
          (_) async => OrderDetail(order(status: OrderStatus.delivered), null));
      await t.pumpWidget(app(const OrderDetailView(orderId: 'o1')));
      await settle(t);
      expect(find.text('Calificar al repartidor'), findsOneWidget);
      expect(find.text('Hacer un reclamo'), findsOneWidget);
      expect(find.text('Repetir pedido'), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsNothing);
    });

    phoneTest('detalle de un pedido que no existe muestra el error', (t) async {
      when(history.fetchOrderDetail('nada')).thenThrow(Exception('x'));
      await t.pumpWidget(app(const OrderDetailView(orderId: 'nada')));
      await settle(t);
      expect(find.text('No pudimos cargar'), findsOneWidget);
    });

    phoneTest('cancelar: elegir motivo, "Otro" pide texto, confirma',
        (t) async {
      when(history.cancelOrder('o1', reason: anyNamed('reason')))
          .thenAnswer((_) async => const CancelResult.ok());
      await t.pumpWidget(app(const CancelOrderView(orderId: 'o1')));
      final confirm = find.text('Confirmar cancelación');
      expect(t.widget<SplgButton>(find.byType(SplgButton).first).onPressed,
          isNull);
      await t.tap(find.text('Otro'));
      await settle(t);
      expect(find.text('0/300'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Me mudé');
      await settle(t);
      await t.tap(confirm);
      await settle(t);
      verify(history.cancelOrder('o1', reason: 'Me mudé')).called(1);
      expect(find.text('Pedido cancelado'), findsOneWidget);
    });

    phoneTest('cancelar: muestra el rechazo del back', (t) async {
      when(history.cancelOrder('o1', reason: anyNamed('reason'))).thenAnswer(
          (_) async => const CancelResult.rejected(
              'El pedido ya está en camino. Contacte al soporte.'));
      await t.pumpWidget(app(const CancelOrderView(orderId: 'o1')));
      await t.tap(find.text('Pedí por error'));
      await settle(t);
      await t.tap(find.text('Confirmar cancelación'));
      await settle(t);
      expect(find.byKey(const Key('cancel-error')), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('Direcciones', () {
    phoneTest('lista con predeterminada y alta', (t) async {
      await t.pumpWidget(app(const AddressesView()));
      await settle(t);
      expect(find.text('Buenos Aires 4114'), findsOneWidget);
      expect(find.text('Predeterminada'), findsOneWidget);
      await t.tap(find.byKey(const Key('address-new')));
      verify(nav.navigateToAddressFormView()).called(1);
    });

    phoneTest('menú de la fila: editar, predeterminar y eliminar', (t) async {
      when(customers.setDefaultAddress('a2'))
          .thenAnswer((_) async => const ApiResult.ok());
      await t.pumpWidget(app(const AddressesView()));
      await settle(t);
      await t.tap(find.byTooltip('Opciones').last);
      await t.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      await t.tap(find.text('Marcar como predeterminada'));
      await t.pumpAndSettle();
      verify(customers.setDefaultAddress('a2')).called(1);
    });

    phoneTest('eliminar pide confirmación', (t) async {
      when(customers.deleteAddress('a2'))
          .thenAnswer((_) async => const ApiResult.ok());
      await t.pumpWidget(app(const AddressesView()));
      await settle(t);
      await t.tap(find.byTooltip('Opciones').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar'));
      await t.pumpAndSettle();
      expect(find.text('Eliminar dirección'), findsOneWidget);
      verifyNever(customers.deleteAddress(any));
      await t.tap(find.text('Eliminar').last);
      await t.pumpAndSettle();
      verify(customers.deleteAddress('a2')).called(1);
    });

    phoneTest('sin direcciones: estado vacío', (t) async {
      when(customers.customer).thenReturn(customerWith());
      await t.pumpWidget(app(const AddressesView()));
      await settle(t);
      expect(
          find.text('Todavía no tenés direcciones guardadas.'), findsOneWidget);
    });

    phoneTest('formulario: valida y guarda', (t) async {
      when(customers.saveAddress(any, editing: anyNamed('editing')))
          .thenAnswer((_) async => const ApiResult.ok());
      await t.pumpWidget(app(const AddressFormView()));
      await t.tap(find.text('Guardar'));
      await settle(t);
      expect(find.text('Ingresá la calle.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('addr-street')), 'Mitre');
      await t.enterText(find.byKey(const Key('addr-number')), '100');
      await t.enterText(find.byKey(const Key('addr-city')), 'Posadas');
      await t.tap(find.text('Guardar'));
      await settle(t);
      verify(customers.saveAddress(any, editing: anyNamed('editing')))
          .called(1);
    });

    phoneTest('formulario de edición precarga la dirección', (t) async {
      await t.pumpWidget(app(AddressFormView(
          address: addr('a1', 'Buenos Aires 4114', city: 'Posadas'))));
      expect(find.text('Editar dirección'), findsOneWidget);
      expect(find.text('Buenos Aires'), findsOneWidget);
      expect(find.text('4114'), findsOneWidget);
    });
  });

  group('Reclamos', () {
    MyClaim claim(String id, ClaimStatus s) => MyClaim(
          claimId: id,
          status: s,
          reason: 'Garrafa en mal estado',
          description: 'Pierde gas',
          createdAt: DateTime(2026, 10, 9, 12),
          orderId: 'o123456',
          orderTotal: 14900,
          resolutionNote:
              s == ClaimStatus.resolved ? 'Se repuso la garrafa' : null,
        );

    phoneTest('lista con estados', (t) async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer((_) async =>
          ApiResult.ok(ClaimsPage(claims: [
            claim('1', ClaimStatus.pending),
            claim('2', ClaimStatus.resolved)
          ], total: 2)));
      await t.pumpWidget(app(const ClaimsView()));
      await settle(t);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('RESUELTO'), findsOneWidget);
    });

    phoneTest('vacío y con error', (t) async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer(
          (_) async => const ApiResult.ok(ClaimsPage(claims: [], total: 0)));
      await t.pumpWidget(app(const ClaimsView()));
      await settle(t);
      expect(find.textContaining('No hiciste ningún reclamo'), findsOneWidget);
    });

    phoneTest('error de carga con reintento', (t) async {
      when(claims.fetchMine(limit: 20, offset: 0)).thenAnswer((_) async =>
          const ApiResult.fail('Sin conexión. Revisá tu internet.'));
      await t.pumpWidget(app(const ClaimsView()));
      await settle(t);
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    phoneTest('detalle: reclamo abierto sin foto ofrece agregarla', (t) async {
      await t.pumpWidget(
          app(ClaimDetailView(claim: claim('1', ClaimStatus.pending))));
      await settle(t);
      expect(find.text('Agregar foto'), findsOneWidget);
      await t.tap(find.byKey(const Key('claim-photo-add')));
      await t.pumpAndSettle();
      expect(find.text('Sacar foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
    });

    phoneTest('detalle: reclamo con foto ofrece cambiarla', (t) async {
      final photos = locator<PhotoService>() as MockPhotoService;
      when(photos.claimPhotoLink('1')).thenAnswer((_) async => ApiResult.ok(
          SignedUrl('https://s3.test/f.jpg',
              DateTime.now().add(const Duration(minutes: 5)))));
      await t.pumpWidget(
          app(ClaimDetailView(claim: claim('1', ClaimStatus.inProcess))));
      await settle(t);
      t.takeException(); // la URL de prueba no se puede descargar
      expect(find.text('Cambiar foto'), findsOneWidget);
    });

    phoneTest('detalle: reclamo resuelto no permite subir foto', (t) async {
      await t.pumpWidget(
          app(ClaimDetailView(claim: claim('2', ClaimStatus.resolved))));
      await settle(t);
      expect(find.byKey(const Key('claim-photo-add')), findsNothing);
    });

    phoneTest('detalle con la respuesta de la distribuidora', (t) async {
      await t.pumpWidget(
          app(ClaimDetailView(claim: claim('2', ClaimStatus.resolved))));
      expect(find.text('Garrafa en mal estado'), findsOneWidget);
      expect(find.textContaining('Se repuso la garrafa'), findsOneWidget);
      expect(find.textContaining('#123456'), findsOneWidget);
    });
  });

  group('Perfil', () {
    phoneTest('muestra los datos y las acciones', (t) async {
      await t.pumpWidget(app(const ProfileView()));
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Editar perfil'), findsOneWidget);
      for (final x in [
        'Información personal',
        'Cambiar contraseña',
        'Mis direcciones',
        'Eliminar cuenta'
      ]) {
        expect(find.text(x), findsOneWidget);
      }
      await t.tap(find.text('Cambiar contraseña'));
      verify(nav.navigateToChangePasswordView()).called(1);
    });

    phoneTest('foto de perfil: sin foto ofrece agregar y elegir el origen',
        (t) async {
      await t.pumpWidget(app(const ProfileView()));
      await settle(t);
      expect(find.text('Agregar foto'), findsOneWidget);
      expect(find.byKey(const Key('profile-photo-remove')), findsNothing);
      await t.tap(find.byKey(const Key('profile-photo-change')));
      await t.pumpAndSettle();
      expect(find.text('Sacar foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
    });

    phoneTest('foto de perfil: con foto ofrece cambiar y quitar', (t) async {
      final pp = locator<ProfilePhotoService>() as MockProfilePhotoService;
      when(pp.url).thenReturn('https://s3.test/foto.png');
      when(pp.hasPhoto).thenReturn(true);
      await t.pumpWidget(app(const ProfileView()));
      await settle(t);
      t.takeException(); // la URL de prueba no se puede descargar
      expect(find.text('Cambiar foto'), findsOneWidget);
      expect(find.byKey(const Key('profile-photo-remove')), findsOneWidget);
    });

    phoneTest('eliminar cuenta: avisa que es definitiva y cancelar no borra',
        (t) async {
      await t.pumpWidget(app(const ProfileView()));
      await t.tap(find.text('Eliminar cuenta'));
      await t.pumpAndSettle();
      expect(find.textContaining('Es definitiva'), findsOneWidget);
      expect(find.textContaining('email'), findsWidgets);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      verifyNever(customers.deleteAccount());
    });

    phoneTest('eliminar cuenta con pedido en curso muestra el 409', (t) async {
      when(customers.deleteAccount()).thenAnswer((_) async =>
          const ApiResult.fail('Tenés pedidos en curso: esperá o cancelalos.'));
      await t.pumpWidget(app(const ProfileView()));
      await t.tap(find.text('Eliminar cuenta'));
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar cuenta').last);
      await t.pumpAndSettle();
      verify(customers.deleteAccount()).called(1);
      expect(find.text('No pudimos eliminar tu cuenta'), findsOneWidget);
      expect(find.text('Tenés pedidos en curso: esperá o cancelalos.'),
          findsOneWidget);
    });

    phoneTest('eliminar cuenta confirmado va a la bienvenida', (t) async {
      when(customers.deleteAccount())
          .thenAnswer((_) async => const ApiResult.ok());
      await t.pumpWidget(app(const ProfileView()));
      await t.tap(find.text('Eliminar cuenta'));
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar cuenta').last);
      await t.pumpAndSettle();
      verify(nav.clearStackAndShow(Routes.welcomeView)).called(1);
    });

    phoneTest('información personal y edición', (t) async {
      await t.pumpWidget(app(const PersonalInfoView()));
      expect(find.textContaining('ana@splg.com'), findsOneWidget);
      expect(find.textContaining('Buenos Aires 4114, Posadas'), findsOneWidget);
      await t.pumpWidget(app(const EditProfileView()));
      expect(find.text('Ana Pérez'), findsOneWidget);
    });

    phoneTest('cambiar contraseña: el botón se habilita al completar',
        (t) async {
      await t.pumpWidget(app(const ChangePasswordView()));
      expect(find.text('Confirmar'), findsOneWidget);
      expect(t.widget<SplgButton>(find.byType(SplgButton)).onPressed, isNull);
    });
  });

  group('Contenido', () {
    phoneTest('ayuda: el recargo de cada medio sale de lo que informa el back',
        (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.paymentTerms()).thenAnswer((_) async => [
            const PaymentTerm(key: 'CASH', name: 'Efectivo', percentage: 0),
            const PaymentTerm(
                key: 'TRANSFER', name: 'Transferencia', percentage: 7.5),
            const PaymentTerm(
                key: 'MERCADOPAGO', name: 'Mercado Pago', percentage: 0),
          ]);
      await t.pumpWidget(app(const HelpView()));
      await settle(t);
      await t.tap(find.text('¿Qué formas de pago hay?'));
      await settle(t);
      expect(
          find.text(
              'Efectivo al recibir, transferencia (con un 7,5 % de recargo) y Mercado Pago.'),
          findsOneWidget);
      expect(find.textContaining('10 %'), findsNothing);
    });

    phoneTest(
        'detalle de una garrafa: los recargos son los del back, o ninguno',
        (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.paymentTerms()).thenAnswer((_) async => [
            const PaymentTerm(key: 'CASH', name: 'Efectivo', percentage: 0),
            const PaymentTerm(
                key: 'TRANSFER', name: 'Transferencia', percentage: 7.5),
            const PaymentTerm(
                key: 'MERCADOPAGO', name: 'Mercado Pago', percentage: 12),
          ]);
      await t.pumpWidget(app(Scaffold(
          body: CylinderDetailSheet(cylinder: cylinder(), onAdd: () {}))));
      await settle(t);
      expect(find.text('Recargo del 7,5 %'), findsOneWidget);
      expect(find.text('Recargo del 12 %'), findsOneWidget);
      expect(find.text('Pagás al recibir el pedido'), findsOneWidget);
      expect(find.textContaining('10 %'), findsNothing);
    });

    phoneTest(
        'detalle de una garrafa: sin respuesta del back no menciona recargos',
        (t) async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.paymentTerms()).thenAnswer((_) async => const []);
      await t.pumpWidget(app(Scaffold(
          body: CylinderDetailSheet(cylinder: cylinder(), onAdd: () {}))));
      await settle(t);
      expect(find.textContaining('Recargo'), findsNothing);
    });

    phoneTest('ayuda: busca y filtra', (t) async {
      await t.pumpWidget(app(const HelpView()));
      expect(find.text('¿Cómo hago un pedido?'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'contraseña');
      await settle(t);
      expect(find.text('¿Cómo cambio mi contraseña?'), findsOneWidget);
      expect(find.text('¿Cómo hago un pedido?'), findsNothing);
      await t.enterText(find.byType(TextField), 'zzzz');
      await settle(t);
      expect(
          find.text('No encontramos nada con esa búsqueda.'), findsOneWidget);
    });

    phoneTest('acerca de', (t) async {
      await t.pumpWidget(app(const AboutView()));
      expect(find.text('¿Qué es SPLG?'), findsOneWidget);
    });

    phoneTest('notificaciones: vacío y con lista agrupada', (t) async {
      await t.pumpWidget(app(const NotificationsView()));
      expect(find.text('¡Nada por aquí!'), findsOneWidget);
      await t.pumpWidget(app(NotificationsScreen(
        now: DateTime(2026, 10, 10),
        items: [
          AppNotification(
              title: 'Tu pedido salió',
              content: 'Ya va para tu casa',
              createdAt: DateTime(2026, 10, 10, 9)),
          AppNotification(
              title: 'Ayer', content: 'x', createdAt: DateTime(2026, 10, 9, 9)),
        ],
      )));
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ayer'), findsWidgets);
    });
  });

  group('Mi carrito', () {
    setUp(() {
      locator.unregister<CartService>();
      final cart = FakeCart();
      cart.seed(
          cart: const Cart(
        cartId: 'c1',
        items: [
          CartLine(
            cartItemId: 'ci-g1',
            gasCylinderId: 'g1',
            type: 'Garrafa 10kg',
            quantity: 2,
            savedUnitPrice: 14900,
            currentUnitPrice: 14155,
            listUnitPrice: 14900,
            discountPercentage: 5,
            priceDifference: 0,
            subtotal: 28310,
            available: true,
            hasEnoughStock: true,
          ),
          CartLine(
            cartItemId: 'ci-g2',
            gasCylinderId: 'g2',
            type: 'Garrafa 5kg',
            quantity: 1,
            savedUnitPrice: 8500,
            currentUnitPrice: 8500,
            priceDifference: 0,
            subtotal: 8500,
            available: true,
            hasEnoughStock: true,
          ),
        ],
        totalUnits: 3,
        total: 36810,
      ));
      locator.registerSingleton<CartService>(cart);
    });

    phoneTest(
        'muestra precio con promoción, lista tachada, % y el total del back',
        (t) async {
      // Con la fuente de prueba (Ahem) el importe grande no entra en 393 px.
      t.view.physicalSize = const Size(600, 852);
      await t.pumpWidget(app(const CartView()));
      await settle(t);
      expect(find.byKey(const Key('cart-total')), findsOneWidget);
      expect(
          t.widget<Text>(find.byKey(const Key('cart-total'))).data, '\$36.810');
      expect(t.widget<Text>(find.byKey(const Key('cart-subtotal-g1'))).data,
          '\$28.310');
      final promo = t
          .widget<Text>(find.byKey(const Key('cart-unit-g1')))
          .textSpan!
          .toPlainText();
      expect(promo, contains('\$14.900'));
      expect(promo, contains('\$14.155 c/u'));
      expect(promo, contains('−5%'));
      final sinPromo = t
          .widget<Text>(find.byKey(const Key('cart-unit-g2')))
          .textSpan!
          .toPlainText();
      expect(sinPromo.trim(), '\$8.500 c/u');
      expect(find.byKey(const Key('cart-total-note')), findsOneWidget);
    });
  });

  group('Confirmación', () {
    setUp(() {
      locator.unregister<CartService>();
      final cart = FakeCart();
      cart.seedOrder(order(
        items: [
          OrderItem(
              cylinder: cylinder(price: 1000, discounts: [
                Discount(quantity: 2, percentage: 10),
              ]),
              quantity: 2),
        ],
        address: addr('a1', 'Buenos Aires 4114'),
      ));
      locator.registerSingleton<CartService>(cart);
      CheckoutViewModel.quoteDebounce = Duration.zero;
      addTearDown(() =>
          CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 400));
      // El precio lo calcula el back: la transferencia suma su recargo.
      final history = locator<HistoryService>() as MockHistoryService;
      when(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart')))
          .thenAnswer((i) async => backQuote(
              paymentSurcharge:
                  (i.positionalArguments.first as Order).paymentMethod ==
                          PaymentMethod.cash
                      ? 0
                      : 180,
              paymentMethod:
                  (i.positionalArguments.first as Order).paymentMethod ==
                          PaymentMethod.cash
                      ? 'cash'
                      : 'transfer',
              paymentSurchargePercentage:
                  (i.positionalArguments.first as Order).paymentMethod ==
                          PaymentMethod.cash
                      ? 0
                      : 10));
      final slots = locator<TimeSlotService>() as MockTimeSlotService;
      when(slots.availabilityFor(any)).thenAnswer((_) async => const [
            TimeSlotAvailability(
                timeSlotId: 's1',
                name: 'Mañana',
                startTime: '08:00:00',
                endTime: '12:00:00',
                remaining: 5),
            TimeSlotAvailability(
                timeSlotId: 's2',
                name: 'Tarde',
                startTime: '16:00:00',
                endTime: '20:00:00',
                remaining: 0),
          ]);
    });

    phoneTest('resumen, total y franjas; la llena queda deshabilitada',
        (t) async {
      await t.pumpWidget(app(const CheckoutView()));
      await settle(t);
      expect(find.text('Confirmación'), findsOneWidget);
      expect(find.text('Buenos Aires 4114'), findsOneWidget);
      expect(find.text('\$1.800'), findsWidgets);
      expect(find.text('Sin cupo'), findsOneWidget);
      // Sin franja elegida no se puede confirmar.
      expect(
          t
              .widget<SplgButton>(
                  find.widgetWithText(SplgButton, 'Confirmar pedido'))
              .onPressed,
          isNull);
      await t.tap(find.byKey(const Key('slot-s1')));
      await settle(t);
      expect(
          t
              .widget<SplgButton>(
                  find.widgetWithText(SplgButton, 'Confirmar pedido'))
              .onPressed,
          isNotNull);
    });

    phoneTest('forma de pago: despliega y suma el recargo de transferencia',
        (t) async {
      await t.pumpWidget(app(const CheckoutView()));
      await settle(t);
      await t.tap(find.byKey(const Key('checkout-payment')));
      await settle(t);
      expect(find.text('Transferencia'), findsOneWidget);
      await t.tap(find.byKey(const Key('pay-online')));
      await settle(t);
      expect(find.text('\$1.980'), findsWidgets);
      expect(
          find.byKey(const Key('checkout-payment-surcharge')), findsOneWidget);
      expect(find.text('Recargo por transferencia (10 %)'), findsOneWidget);
    });

    // El % y el monto salen de la cotización del back: la app no calcula nada.
    for (final c in [
      (0.0, 0.0, '\$1.800'),
      (7.5, 135.0, '\$1.935'),
      (10.0, 180.0, '\$1.980'),
    ]) {
      phoneTest(
          'con recargo de transferencia en ${c.$1} %: lo que dice la cotización',
          (t) async {
        final history = locator<HistoryService>() as MockHistoryService;
        when(history.quoteOrder(any,
                timeSlotId: anyNamed('timeSlotId'),
                fromCart: anyNamed('fromCart')))
            .thenAnswer((_) async => backQuote(
                paymentSurcharge: c.$2,
                paymentMethod: 'transfer',
                paymentSurchargePercentage: c.$1));
        await t.pumpWidget(app(const CheckoutView()));
        await settle(t);
        await t.tap(find.byKey(const Key('checkout-payment')));
        await settle(t);
        await t.tap(find.byKey(const Key('pay-online')));
        await settle(t);
        expect(find.text(c.$3), findsWidgets);
        if (c.$2 == 0) {
          expect(find.byKey(const Key('checkout-payment-surcharge')),
              findsNothing);
        } else {
          expect(
              find.text(
                  'Recargo por transferencia (${c.$1 == 7.5 ? '7,5' : '10'} %)'),
              findsOneWidget);
        }
      });
    }
  });
  group('Modificar pedido', () {
    setUp(() {
      EditOrderViewModel.quoteDebounce = Duration.zero;
      EditOrderViewModel.now = () => DateTime(2026, 10, 14);
      addTearDown(() {
        EditOrderViewModel.quoteDebounce = const Duration(milliseconds: 400);
        EditOrderViewModel.now = DateTime.now;
      });
      final history = locator<HistoryService>() as MockHistoryService;
      when(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              orderId: anyNamed('orderId')))
          .thenAnswer((i) async => backQuote(
              qty: (i.positionalArguments.first as Order)
                  .items
                  .fold<int>(0, (n, it) => n + it.quantity),
              zoneSurcharge: 50,
              paymentSurcharge:
                  (i.positionalArguments.first as Order).paymentMethod ==
                          PaymentMethod.cash
                      ? 0
                      : 180));
      final customersMock = locator<CustomerService>() as MockCustomerService;
      when(customersMock.customer)
          .thenReturn(customerWith([addr('a1', 'Mitre 100', primary: true)]));
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenAnswer((_) async => [
            cylinder(price: 1000),
            cylinder(id: 'g2', price: 2000),
          ]);
      final slots = locator<TimeSlotService>() as MockTimeSlotService;
      when(slots.availabilityFor(any)).thenAnswer((_) async => const [
            TimeSlotAvailability(
                timeSlotId: 's1',
                name: 'Mañana',
                startTime: '08:00:00',
                endTime: '12:00:00',
                remaining: 5),
          ]);
    });

    Order editable() => order(
          items: [OrderItem(cylinder: cylinder(price: 1000), quantity: 2)],
          address: addr('a1', 'Mitre 100'),
        ).copyWith(
            deliveryWindowStart: '08:00:00', deliveryWindowEnd: '12:00:00');

    phoneTest('muestra el pedido, el total del back y guarda', (t) async {
      final history = locator<HistoryService>() as MockHistoryService;
      when(history.updateOrder(any, any, timeSlotId: anyNamed('timeSlotId')))
          .thenAnswer((_) async =>
              UpdateOrderResult(success: true, order: order(total: 1850)));
      await t.pumpWidget(app(EditOrderView(order: editable())));
      await settle(t);

      expect(find.text('Sin fecha agendada'), findsOneWidget);
      // Sin cambios no hay qué guardar.
      expect(
          t
              .widget<SplgButton>(
                  find.widgetWithText(SplgButton, 'Guardar cambios'))
              .onPressed,
          isNull);
      expect(find.text('Modificar pedido'), findsOneWidget);
      expect(find.text('Mitre 100'), findsOneWidget);
      expect(find.byKey(const Key('edit-total')), findsOneWidget);
      expect(find.text('\$1.850'), findsWidgets);
      expect(find.byKey(const Key('edit-zone-surcharge')), findsOneWidget);

      await t.tap(find.byTooltip('Agregar uno').first);
      await settle(t);
      expect(find.text('\$2.750'), findsWidgets);

      await t.tap(find.widgetWithText(SplgButton, 'Guardar cambios'));
      await settle(t);
      verify(history.updateOrder('o1', any, timeSlotId: null)).called(1);
    });

    phoneTest('la forma de pago no ofrece Mercado Pago', (t) async {
      await t.pumpWidget(app(EditOrderView(order: editable())));
      await settle(t);
      await t.tap(find.byKey(const Key('edit-payment')));
      await settle(t);

      expect(find.byKey(const Key('edit-pay-cash')), findsOneWidget);
      expect(find.byKey(const Key('edit-pay-online')), findsOneWidget);
      expect(find.byKey(const Key('edit-pay-mercadoPago')), findsNothing);
      expect(find.text('Mercado Pago'), findsNothing);
    });
  });
}
