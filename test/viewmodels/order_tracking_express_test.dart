import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/tracking_routes.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/maps/route_service.dart';
import 'package:splg_lib/maps/route_tracker.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderTrackingService tracking;
  late StreamController<void> degraded;
  late StreamController<void> changes;
  late StreamController<DriverInfo> drivers;
  late StreamController<String> statuses;
  late StreamController<DriverLocationUpdate> locations;
  late Map<String, dynamic> server;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    drivers = StreamController<DriverInfo>.broadcast();
    statuses = StreamController<String>.broadcast();
    degraded = StreamController<void>.broadcast();
    when(tracking.expressDegradedUpdates).thenAnswer((_) => degraded.stream);
    changes = StreamController<void>.broadcast();
    when(tracking.orderChanges).thenAnswer((_) => changes.stream);
    locations = StreamController<DriverLocationUpdate>.broadcast();
    when(tracking.driverUpdates).thenAnswer((_) => drivers.stream);
    when(tracking.orderStatusUpdates).thenAnswer((_) => statuses.stream);
    when(tracking.driverLocationUpdates).thenAnswer((_) => locations.stream);
    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup());
    server = {'status': 'pending'};
    when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async => server);
  });

  tearDown(() {
    drivers.close();
    statuses.close();
    degraded.close();
    changes.close();
    locations.close();
    locator.reset();
  });

  Future<OrderTrackingViewModel> abrir({
    RouteTrackerFactory? routeTracker,
    Duration poll = const Duration(hours: 1),
  }) async {
    final model = OrderTrackingViewModel(
      orderId: 'o1',
      pollInterval: poll,
      routeTracker: routeTracker ??
          (d) => RouteTracker(service: SplgRouteService(), destination: d),
      iconLoader: () async => null,
    );
    await model.initialize();
    return model;
  }

  group('aviso del express', () {
    test('express buscando moto: lo explica', () async {
      server = {'status': 'pending', 'deliveryMode': 'express'};
      final model = await abrir();

      expect(model.expressNotice, contains('repartidores en moto'));
      model.dispose();
    });

    test('pasó al reparto común: sin recargo y con la devolución', () async {
      server = {
        'status': 'pending',
        'deliveryMode': 'standard',
        'expressSurchargeAmount': 2350,
        'expressDegradedAt': '2026-10-18T15:00:00.000Z',
        'paymentStatus': 'paid',
        'paymentMethod': 'mercadopago',
      };
      final model = await abrir();

      final text = model.expressNotice!;
      expect(text, contains('Ningún repartidor en moto'));
      expect(text, contains('2.350'));
      expect(text, contains('se te devuelve'));
      model.dispose();
    });

    test('un pedido común no tiene aviso', () async {
      server = {'status': 'pending', 'deliveryMode': 'standard'};
      final model = await abrir();

      expect(model.expressNotice, isNull);
      model.dispose();
    });

    test('un express ya asignado no repite que busca moto', () async {
      server = {'status': 'accepted', 'deliveryMode': 'express'};
      final model = await abrir();

      expect(model.expressNotice, isNull);
      model.dispose();
    });

    test('el aviso del socket actualiza el pedido aunque siga pendiente',
        () async {
      server = {'status': 'pending', 'deliveryMode': 'express'};
      final model = await abrir();
      expect(model.expressNotice, contains('lo ofrecemos'));

      server = {
        'status': 'pending',
        'deliveryMode': 'standard',
        'expressSurchargeAmount': 2350,
        'expressDegradedAt': '2026-10-18T15:00:00.000Z',
      };
      degraded.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(model.expressNotice, contains('Ningún repartidor en moto'));
      model.dispose();
    });

    test('sin cobro online no promete devolución', () async {
      server = {
        'status': 'pending',
        'deliveryMode': 'standard',
        'expressDegradedAt': '2026-10-18T15:00:00.000Z',
        'paymentStatus': 'pending',
      };
      final model = await abrir();

      expect(model.expressNotice, isNot(contains('devuelve')));
      model.dispose();
    });
  });

  group('el pedido cambió sin cambiar de estado', () {
    test('modificado, pago aprobado o reintegrado: vuelve a leer el pedido',
        () async {
      final model = await abrir();
      clearInteractions(tracking);

      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(tracking.fetchOrderById('o1', 'tok')).called(1);
      model.dispose();
    });
  });
}
