import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_view.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/splg_lib.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockOrderTrackingService tracking;
  late Map<String, dynamic>? server;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    when(tracking.driverUpdates).thenAnswer((_) => const Stream.empty());
    when(tracking.orderStatusUpdates).thenAnswer((_) => const Stream.empty());
    when(tracking.driverLocationUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup());
    when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async => server);
    OrderTrackingView.debugMapBuilder =
        (_, __) => const ColoredBox(color: Colors.black12);
    OrderTrackingView.debugViewModelFactory = (id) => OrderTrackingViewModel(
          orderId: id,
          pollInterval: const Duration(hours: 1),
          iconLoader: () async => null,
        );
  });

  tearDown(() {
    OrderTrackingView.debugMapBuilder = null;
    OrderTrackingView.debugViewModelFactory = null;
    locator.reset();
  });

  Future<void> abrir(WidgetTester t, Map<String, dynamic>? pedido) async {
    server = pedido;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OrderTrackingView(orderId: 'o1'),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('pendiente: busca repartidor y deja cancelar', (t) async {
    await abrir(t, {'status': 'pending'});

    expect(find.text('Buscando al repartidor más cercano...'), findsOneWidget);
    expect(find.byKey(const Key('tracking-cancel')), findsOneWidget);
    expect(find.byKey(const Key('tracking-call')), findsNothing);
  });

  testWidgets('entregado: confirma y ofrece calificar, sin botón de cancelar',
      (t) async {
    await abrir(t, {'status': 'delivered'});

    expect(find.byKey(const Key('tracking-finished-title')), findsOneWidget);
    expect(find.text('Entregamos tu pedido'), findsOneWidget);
    expect(find.byKey(const Key('tracking-rate')), findsOneWidget);
    expect(find.byKey(const Key('tracking-cancel')), findsNothing);
    expect(find.text('Buscando al repartidor más cercano...'), findsNothing);
  });

  testWidgets('cancelado: muestra el motivo del back y no deja cancelar',
      (t) async {
    await abrir(t, {
      'status': 'cancelled',
      'cancellation_reason': 'Sin stock de garrafas',
    });

    expect(find.text('Pedido cancelado'), findsOneWidget);
    expect(find.text('Motivo: Sin stock de garrafas'), findsOneWidget);
    expect(find.byKey(const Key('tracking-cancel')), findsNothing);
    expect(find.byKey(const Key('tracking-rate')), findsNothing);
  });

  testWidgets('en camino: datos del repartidor, patente y QR', (t) async {
    await abrir(t, {
      'status': 'on_the_way',
      'driver': {
        'userId': 'd1',
        'fullName': 'Juan Pérez',
        'phoneNumber': '+54911',
        'ratingAverage': 4.8,
        'ratingCount': 12,
        'location': null,
      },
      'vehicle': {'patent': 'AB123CD', 'brand': 'Toyota', 'model': 'Hilux'},
    });

    expect(find.text('Juan está en camino'), findsOneWidget);
    expect(find.text('AB123CD'), findsOneWidget);
    expect(find.text('Toyota Hilux'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.byKey(const Key('tracking-confirm-qr')), findsOneWidget);
    expect(find.byKey(const Key('tracking-cancel')), findsNothing);
    final call = t.widget<SplgButton>(find.byKey(const Key('tracking-call')));
    expect(call.onPressed, isNotNull);
  });

  testWidgets('sin teléfono del repartidor, llamar queda deshabilitado',
      (t) async {
    await abrir(t, {
      'status': 'accepted',
      'driver': {
        'userId': 'd1',
        'fullName': 'Juan Pérez',
        'phoneNumber': null,
        'ratingAverage': 0,
        'ratingCount': 0,
        'location': null,
      },
    });

    final call = t.widget<SplgButton>(find.byKey(const Key('tracking-call')));
    expect(call.onPressed, isNull);
    expect(find.text('Sin calificaciones'), findsOneWidget);
  });

  testWidgets('si el pedido no carga, error claro y Reintentar', (t) async {
    await abrir(t, null);

    expect(find.text('No pudimos cargar'), findsOneWidget);
    expect(find.byKey(const Key('tracking-retry')), findsOneWidget);

    server = {'status': 'pending'};
    await t.tap(find.byKey(const Key('tracking-retry')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('tracking-cancel')), findsOneWidget);
  });

  testWidgets('sin teléfono explica por qué Llamar está deshabilitado',
      (t) async {
    await abrir(t, {
      'status': 'accepted',
      'driver': {
        'userId': 'd1',
        'fullName': 'Juan Pérez',
        'phoneNumber': null,
        'ratingAverage': 0,
        'ratingCount': 0,
        'location': null,
      },
    });

    expect(find.byKey(const Key('tracking-contact-hint')), findsOneWidget);
  });

  testWidgets('con teléfono no hay aviso de contacto', (t) async {
    await abrir(t, {
      'status': 'accepted',
      'driver': {
        'userId': 'd1',
        'fullName': 'Juan Pérez',
        'phoneNumber': '+54911',
        'ratingAverage': 0,
        'ratingCount': 0,
        'location': null,
      },
    });

    expect(find.byKey(const Key('tracking-contact-hint')), findsNothing);
  });

  testWidgets('pedido que ya no existe (404/410): mensaje claro y Volver',
      (t) async {
    when(tracking.fetchOrderById('o1', 'tok'))
        .thenAnswer((_) async => throw orderGoneFailure);
    await abrir(t, null);

    expect(find.text(kOrderGoneText), findsOneWidget);
    expect(find.byKey(const Key('tracking-retry')), findsNothing);
    expect(find.byKey(const Key('tracking-back')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await t.tap(find.byKey(const Key('tracking-back')));
    await t.pump();
    verify((locator<NavigationService>() as MockNavigationService).back())
        .called(1);
  });

  testWidgets('con la sesión vencida no ofrece Reintentar', (t) async {
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => null);
    await abrir(t, {'status': 'pending'});

    expect(
        find.text('Tu sesión venció. Volvé a iniciar sesión.'), findsOneWidget);
    expect(find.byKey(const Key('tracking-retry')), findsNothing);
  });

  testWidgets('cancelar pasa por la pantalla de motivo', (t) async {
    await abrir(t, {'status': 'pending'});
    await t.tap(find.byKey(const Key('tracking-cancel')));
    await t.pump();

    verify((locator<NavigationService>() as MockNavigationService)
            .navigateTo<dynamic>(Routes.cancelOrderView,
                arguments: anyNamed('arguments'),
                id: anyNamed('id'),
                preventDuplicates: anyNamed('preventDuplicates'),
                parameters: anyNamed('parameters'),
                transition: anyNamed('transition')))
        .called(1);
  });
}
