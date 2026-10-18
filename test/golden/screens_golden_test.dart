import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/ui/views/home/widgets/home_map.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/ui/views/address_form/address_form_view.dart';
import 'package:splg_customer/ui/views/addresses/addresses_view.dart';
import 'package:splg_customer/ui/views/cancel_order/cancel_order_view.dart';
import 'package:splg_customer/ui/views/checkout/checkout_view.dart';
import 'package:splg_customer/ui/views/edit_order/edit_order_view.dart';
import 'package:splg_customer/ui/views/edit_order/edit_order_viewmodel.dart';
import 'package:splg_customer/ui/views/claims/claims_view.dart';
import 'package:splg_customer/ui/views/help/help_view.dart';
import 'package:splg_customer/ui/views/home/home_view.dart';
import 'package:splg_customer/ui/views/login/login_view.dart';
import 'package:splg_customer/ui/views/notifications/notifications_view.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_view.dart';
import 'package:splg_customer/ui/views/orders/orders_view.dart';
import 'package:splg_customer/ui/views/profile/profile_view.dart';
import 'package:splg_customer/ui/views/signup/signup_view.dart';
import 'package:splg_customer/ui/views/startup/startup_view.dart';
import 'package:splg_customer/ui/views/welcome/welcome_view.dart';
import 'package:splg_customer/ui/widgets/app_drawer/app_drawer.dart';
import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/splg_lib.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

/// Goldens de las pantallas del cliente (393x852, 1x).
Future<void> pumpScreen(WidgetTester t, Widget home,
    {bool drawer = false, bool settle = true}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: home,
  ));
  await t.pump();
  if (drawer) {
    t.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  }
  // Las ilustraciones y las fotos se leen del bundle (I/O real).
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final img = e.widget as Image;
      await precacheImage(img.image, e);
    }
  });
  if (settle) {
    await t.pumpAndSettle(const Duration(milliseconds: 50));
  } else {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> check(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

void main() {
  late MockCustomerService customers;
  late MockHistoryService history;

  void stubPage(List<Order> orders) => when(history.fetchOrdersPage(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async =>
          OrdersPage(orders: orders, total: orders.length, offset: 0));

  setUpAll(() => initializeDateFormatting('es_AR', null));
  setUp(() => HomeMap.placeholder = true);
  tearDown(() => HomeMap.placeholder = false);

  setUp(() {
    registerServices();
    customers = locator<CustomerService>() as MockCustomerService;
    history = locator<HistoryService>() as MockHistoryService;
    when(customers.customer).thenReturn(customerWith([
      addr('a1', 'Buenos Aires 4114', primary: true, city: 'Posadas'),
      addr('a2', 'Mitre 1234', city: 'Posadas'),
    ]));
    when(customers.isUserLoggedIn).thenReturn(true);
    when(history.history).thenReturn(<Order>[]);
    stubPage(const []);
  });
  tearDown(() => locator.reset());

  testGoldens('Bienvenida', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const WelcomeView());
    await check(t, 'welcome');
  });

  testGoldens('Arranque', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const StartupView(), settle: false);
    await check(t, 'startup');
  });

  testGoldens('Login', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const LoginView());
    await check(t, 'login');
  });

  testGoldens('Registro, paso 2', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const SignupView());
    await t.enterText(find.byKey(const Key('signup-name')), 'Ana Pérez');
    await t.enterText(find.byKey(const Key('signup-phone')), '3815550999');
    await t.tap(find.text('Siguiente'));
    await t.pumpAndSettle();
    await check(t, 'signup_step2');
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
            cylinder(id: 'g2', price: 21500),
          ]);
    });

    testGoldens('Inicio con el pedido en curso', (t) async {
      await loadAppFonts();
      when(history.history).thenReturn(
          [order(id: 'abc123456', status: OrderStatus.outForDelivery)]);
      await pumpScreen(t, const HomeView());
      await check(t, 'home');
    });

    testGoldens('Inicio sin pedido en curso', (t) async {
      await loadAppFonts();
      await pumpScreen(t, const HomeView());
      await check(t, 'home_idle');
    });

    testGoldens('Catálogo en la hoja del Inicio', (t) async {
      await loadAppFonts();
      await pumpScreen(t, const HomeView());
      await t.tap(find.byKey(const Key('home-catalog-field')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Agregar uno').first);
      await t.pumpAndSettle();
      await check(t, 'home_catalog');
    });

    testGoldens('Menú lateral', (t) async {
      await loadAppFonts();
      await pumpScreen(t, const Scaffold(drawer: AppDrawer()), drawer: true);
      await check(t, 'menu');
    });
  });

  testGoldens('Mi perfil', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const ProfileView());
    await check(t, 'profile');
  });

  testGoldens('Mis pedidos', (t) async {
    await loadAppFonts();
    stubPage([
      order(id: 'p1', status: OrderStatus.pending),
      order(id: 'p2', status: OrderStatus.delivered, total: 5000),
      order(id: 'p3', status: OrderStatus.cancelled),
    ]);
    await pumpScreen(t, const OrdersView());
    await check(t, 'orders');
  });

  testGoldens('Mis pedidos vacío', (t) async {
    await loadAppFonts();
    stubPage(const []);
    await pumpScreen(t, const OrdersView());
    await check(t, 'orders_empty');
  });

  testGoldens('Detalle del pedido', (t) async {
    await loadAppFonts();
    when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
        order(status: OrderStatus.pending, total: 1230),
        const OrderBreakdown(
            total: 1230,
            itemsSubtotal: 1000,
            zoneSurcharge: 50,
            zoneName: 'Centro')));
    await pumpScreen(t, const OrderDetailView(orderId: 'o1'));
    await check(t, 'order_detail');
  });

  testGoldens('Cancelar pedido', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const CancelOrderView(orderId: 'o1'));
    await t.tap(find.text('Pedí por error'));
    await t.pumpAndSettle();
    await check(t, 'cancel_order');
  });

  testGoldens('Mis direcciones', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const AddressesView());
    await check(t, 'addresses');
  });

  testGoldens('Nueva dirección', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const AddressFormView());
    await check(t, 'address_form');
  });

  testGoldens('Mis reclamos', (t) async {
    await loadAppFonts();
    final claims = locator<ClaimService>() as MockClaimService;
    when(claims.fetchMine(limit: 20, offset: 0))
        .thenAnswer((_) async => ApiResult.ok(ClaimsPage(claims: [
              MyClaim(
                  claimId: '1',
                  status: ClaimStatus.pending,
                  reason: 'Garrafa en mal estado',
                  description: 'Pierde gas',
                  createdAt: DateTime(2026, 10, 9, 12),
                  orderId: 'o1'),
              MyClaim(
                  claimId: '2',
                  status: ClaimStatus.resolved,
                  reason: 'Demora excesiva',
                  description: 'Tardó dos horas',
                  createdAt: DateTime(2026, 10, 7, 9),
                  orderId: 'o2'),
            ], total: 2)));
    await pumpScreen(t, const ClaimsView());
    await check(t, 'claims');
  });

  testGoldens('Notificaciones vacías', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const NotificationsView());
    await check(t, 'notifications_empty');
  });

  testGoldens('Ayuda', (t) async {
    await loadAppFonts();
    await pumpScreen(t, const HelpView());
    await check(t, 'help');
  });

  testGoldens('Confirmación', (t) async {
    await loadAppFonts();
    CheckoutViewModel.now = () => DateTime(2026, 10, 12);
    addTearDown(() => CheckoutViewModel.now = DateTime.now);
    locator.unregister<CartService>();
    final cart = FakeCart();
    cart.seedOrder(order(
      items: [
        OrderItem(
            cylinder: cylinder(price: 14900, discounts: [
              Discount(quantity: 2, percentage: 5),
            ]),
            quantity: 2),
      ],
      address: addr('a1', 'Buenos Aires 4114'),
    ));
    locator.registerSingleton<CartService>(cart);
    CheckoutViewModel.quoteDebounce = Duration.zero;
    addTearDown(() =>
        CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 400));
    final history = locator<HistoryService>() as MockHistoryService;
    when(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')))
        .thenAnswer((_) async => backQuote(unit: 14155));
    final slots = locator<TimeSlotService>() as MockTimeSlotService;
    when(slots.availabilityFor(any)).thenAnswer((_) async => const [
          TimeSlotAvailability(
              timeSlotId: 's1',
              name: 'Mañana',
              startTime: '08:00:00',
              endTime: '12:00:00',
              remaining: 60),
          TimeSlotAvailability(
              timeSlotId: 's2',
              name: 'Tarde',
              startTime: '16:00:00',
              endTime: '20:00:00',
              remaining: 0),
        ]);
    await pumpScreen(t, const CheckoutView());
    await t.tap(find.byKey(const Key('slot-s1')));
    await t.pumpAndSettle();
    await check(t, 'checkout');
  });
  testGoldens('Modificar pedido', (t) async {
    await loadAppFonts();
    EditOrderViewModel.now = () => DateTime(2026, 10, 12);
    EditOrderViewModel.quoteDebounce = Duration.zero;
    addTearDown(() {
      EditOrderViewModel.now = DateTime.now;
      EditOrderViewModel.quoteDebounce = const Duration(milliseconds: 400);
    });
    final history = locator<HistoryService>() as MockHistoryService;
    when(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'),
            fromCart: anyNamed('fromCart'),
            orderId: anyNamed('orderId')))
        .thenAnswer((_) async =>
            backQuote(unit: 14155, zoneSurcharge: 900, zoneName: 'Centro'));
    final customersMock = locator<CustomerService>() as MockCustomerService;
    when(customersMock.customer).thenReturn(
        customerWith([addr('a1', 'Buenos Aires 4114', primary: true)]));
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenAnswer((_) async => [
          cylinder(price: 14900, discounts: [
            Discount(quantity: 2, percentage: 5),
          ]),
          cylinder(id: 'g2', type: 'Garrafa 15kg', price: 8500),
        ]);
    final slots = locator<TimeSlotService>() as MockTimeSlotService;
    when(slots.availabilityFor(any)).thenAnswer((_) async => const [
          TimeSlotAvailability(
              timeSlotId: 's1',
              name: 'Mañana',
              startTime: '08:00:00',
              endTime: '12:00:00',
              remaining: 60),
          TimeSlotAvailability(
              timeSlotId: 's2',
              name: 'Tarde',
              startTime: '16:00:00',
              endTime: '20:00:00',
              remaining: 0),
        ]);
    final editable = order(
      items: [OrderItem(cylinder: cylinder(price: 14900), quantity: 2)],
      address: addr('a1', 'Buenos Aires 4114'),
    ).copyWith(deliveryWindowStart: '08:00:00', deliveryWindowEnd: '12:00:00');
    await pumpScreen(
        t,
        EditOrderView(
            order: editable,
            breakdown: const OrderBreakdown(
                total: 1000, scheduledDate: '2026-10-12')));
    await check(t, 'edit_order');
  });
}
