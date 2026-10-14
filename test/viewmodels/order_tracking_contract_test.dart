import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_driver_reader.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/maps/route_service.dart';
import 'package:splg_lib/maps/route_tracker.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

/// Contrato de `GET /orders/:id` y de los eventos del socket (docs/PEDIDOS.md
/// del back): bloque `driver`, `cancelledBy` y 404/410.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderTrackingService tracking;
  late StreamController<String> statuses;
  late StreamController<String> cancelledBys;
  late StreamController<DriverLocationUpdate> locations;
  Map<String, dynamic>? server;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    statuses = StreamController<String>.broadcast();
    cancelledBys = StreamController<String>.broadcast();
    locations = StreamController<DriverLocationUpdate>.broadcast();
    when(tracking.orderStatusUpdates).thenAnswer((_) => statuses.stream);
    when(tracking.cancelledBys).thenAnswer((_) => cancelledBys.stream);
    when(tracking.driverLocationUpdates).thenAnswer((_) => locations.stream);
    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup());
    server = {'status': 'pending'};
    when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async => server);
  });

  tearDown(() {
    statuses.close();
    cancelledBys.close();
    locations.close();
    locator.reset();
  });

  OrderTrackingViewModel vm({Duration poll = const Duration(hours: 1)}) =>
      OrderTrackingViewModel(
        orderId: 'o1',
        pollInterval: poll,
        routeTracker: (d) =>
            RouteTracker(service: SplgRouteService(), destination: d),
        iconLoader: () async => null,
      );

  Future<OrderTrackingViewModel> abrir(Map<String, dynamic> pedido,
      {Duration poll = const Duration(hours: 1)}) async {
    server = pedido;
    final model = vm(poll: poll);
    await model.initialize();
    return model;
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  Map<String, dynamic> driver({
    String? phone = '+54911',
    num average = 4.8,
    num count = 12,
    Map<String, dynamic>? location,
  }) =>
      {
        'userId': 'd1',
        'fullName': 'Ana Gómez',
        'phoneNumber': phone,
        'ratingAverage': average,
        'ratingCount': count,
        'location': location,
      };

  group('bloque driver', () {
    test('nombre, teléfono y calificación salen del bloque del back', () async {
      final model = await abrir({
        'status': 'accepted',
        'delivery_id': 'd1',
        'driver': driver(),
      });

      expect(model.driverName, 'Ana Gómez');
      expect(model.hasDriverPhone, isTrue);
      expect(model.driverRating, 4.8);
      model.dispose();
    });

    test('sin calificaciones (count 0) no muestra un 0,0', () async {
      final model = await abrir({
        'status': 'accepted',
        'driver': driver(average: 0, count: 0),
      });

      expect(model.driverRating, isNull);
      model.dispose();
    });

    test('driver null: el estado se muestra sin chofer y sin romperse',
        () async {
      final model = await abrir({
        'status': 'accepted',
        'delivery_name': 'Ana Gómez',
        'driver': null,
      });

      expect(model.stage, TrackingStage.assigned);
      expect(model.statusTitle, 'Ana fue asignado a tu pedido');
      expect(model.hasDriverPhone, isFalse);
      expect(model.driverRating, isNull);
      expect(model.driverPosition, isNull);
      model.dispose();
    });

    test('driver null sin ningún dato: el título no inventa un nombre',
        () async {
      final model = await abrir({'status': 'out_for_delivery', 'driver': null});

      expect(model.stage, TrackingStage.inProgress);
      expect(model.driverName, 'Repartidor');
      expect(model.hasDriverPhone, isFalse);
      model.dispose();
    });

    test(
        'si el pedido vuelve con driver null, no quedan el teléfono ni la '
        'calificación del bloque anterior', () async {
      final model = await abrir({'status': 'accepted', 'driver': driver()});
      expect(model.hasDriverPhone, isTrue);

      server = {'status': 'accepted', 'driver': null};
      await model.poll();

      expect(model.hasDriverPhone, isFalse);
      expect(model.driverRating, isNull);
      model.dispose();
    });

    test('ya no lee las claves viejas (name, phone, rating)', () async {
      final model = await abrir({
        'status': 'accepted',
        'driver': {'name': 'Juan', 'phone': '+54911', 'rating': 5},
      });

      expect(model.hasDriverPhone, isFalse);
      expect(model.driverRating, isNull);
      model.dispose();
    });

    test('OrderDriverReader: location null es "sin posición reciente"', () {
      final snapshot = OrderDriverReader.read({
        'status': 'out_for_delivery',
        'driver': driver(location: null),
      });

      expect(snapshot.hasBlock, isTrue);
      expect(snapshot.lastLocation, isNull);
    });
  });

  group('ubicación del chofer en el pedido', () {
    String hace(int segundos) => DateTime.now()
        .toUtc()
        .subtract(Duration(seconds: segundos))
        .toIso8601String();

    test('en camino con ubicación reciente: dibuja la camioneta', () async {
      final model = await abrir({
        'status': 'out_for_delivery',
        'driver': driver(location: {
          'lat': -27.36,
          'lng': -55.89,
          'at': hace(5),
        }),
      });

      expect(model.driverPosition, const LatLng(-27.36, -55.89));
      model.dispose();
    });

    test('en camino sin ubicación (null): sin camioneta y sin error', () async {
      final model = await abrir({
        'status': 'out_for_delivery',
        'driver': driver(location: null),
      });

      expect(model.driverPosition, isNull);
      expect(model.loadError, isNull);
      model.dispose();
    });

    test('una ubicación del pedido más vieja que la del socket no la pisa',
        () async {
      final model = await abrir({
        'status': 'out_for_delivery',
        'driver': driver(location: null),
      });
      locations.add(
          const DriverLocationUpdate(lat: -27.30, lng: -55.80, heading: 0));
      await pump();

      server = {
        'status': 'out_for_delivery',
        'driver': driver(location: {
          'lat': -27.00,
          'lng': -55.00,
          'at': hace(600),
        }),
      };
      await model.poll();

      expect(model.driverPosition, const LatLng(-27.30, -55.80));
      model.dispose();
    });

    test('si el socket se cayó, la del pedido (más nueva) mueve la camioneta',
        () async {
      final model = await abrir({
        'status': 'out_for_delivery',
        'driver': driver(location: {
          'lat': -27.36,
          'lng': -55.89,
          'at': hace(60),
        }),
      });

      server = {
        'status': 'out_for_delivery',
        'driver': driver(location: {
          'lat': -27.37,
          'lng': -55.90,
          'at': hace(1),
        }),
      };
      await model.poll();

      expect(model.driverPosition, const LatLng(-27.37, -55.90));
      model.dispose();
    });
  });

  group('cancelledBy', () {
    Future<String?> detalle(Map<String, dynamic> extra) async {
      final model = await abrir({'status': 'cancelled', ...extra});
      final text = model.finishedDetail;
      model.dispose();
      return text;
    }

    test('dice quién canceló', () async {
      expect(await detalle({'cancelledBy': 'customer'}), 'Lo cancelaste vos.');
      expect(await detalle({'cancelledBy': 'admin'}),
          'Lo canceló la distribuidora.');
      expect(await detalle({'cancelledBy': 'driver'}),
          'Lo canceló el repartidor.');
      expect(await detalle({'cancelledBy': 'system'}),
          'Se canceló automáticamente.');
    });

    test('suma el motivo, salvo el "Cancelado por <rol>" que repite', () async {
      expect(
          await detalle({
            'cancelledBy': 'admin',
            'cancellation_reason': 'Sin stock de garrafas',
          }),
          'Lo canceló la distribuidora. Motivo: Sin stock de garrafas');
      expect(
          await detalle({
            'cancelledBy': 'customer',
            'cancellation_reason': 'Cancelado por customer',
          }),
          'Lo cancelaste vos.');
    });

    test(
        'pedido anterior al historial (cancelledBy null) sigue mostrando el '
        'motivo', () async {
      expect(
          await detalle({
            'cancelledBy': null,
            'cancellation_reason': 'Zona sin cobertura',
          }),
          'Motivo: Zona sin cobertura');
    });

    test('el evento del socket trae quién canceló', () async {
      final model = await abrir({'status': 'pending'});

      cancelledBys.add('admin');
      server = {
        'status': 'cancelled',
        'cancellation_reason': 'Sin stock',
        'cancelledBy': 'admin',
      };
      statuses.add('cancelled');
      await pump();
      await pump();

      expect(model.finishedDetail,
          'Lo canceló la distribuidora. Motivo: Sin stock');
      model.dispose();
    });
  });

  group('404 / 410 al leer el pedido', () {
    void gone() => when(tracking.fetchOrderById('o1', 'tok'))
        .thenAnswer((_) async => throw orderGoneFailure);

    test(
        'la primera carga no queda en carga infinita ni reintenta: mensaje '
        'claro y sin Reintentar', () async {
      gone();
      final model = vm(poll: const Duration(milliseconds: 20));
      await model.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(model.isBusy, isFalse);
      expect(model.hasOrderLoaded, isFalse);
      expect(model.loadError, kOrderGoneText);
      expect(model.canRetryLoad, isFalse);
      verify(tracking.fetchOrderById('o1', 'tok')).called(1);
      verifyNever(tracking.subscribeToOrder(
        orderId: anyNamed('orderId'),
        customerId: anyNamed('customerId'),
        tokenProvider: anyNamed('tokenProvider'),
      ));
      model.dispose();
    });

    test(
        'si el pedido desaparece con la pantalla abierta: avisa, vuelve y '
        'deja de consultar', () async {
      final model = await abrir({'status': 'pending'},
          poll: const Duration(milliseconds: 20));
      clearInteractions(tracking);
      gone();

      await Future<void>.delayed(const Duration(milliseconds: 120));

      verify((locator<DialogService>() as MockDialogService).showDialog(
        title: 'Pedido no disponible',
        description: kOrderGoneText,
        buttonTitle: 'Aceptar',
      )).called(1);
      verify((locator<NavigationService>() as MockNavigationService).back())
          .called(1);
      verify(tracking.fetchOrderById('o1', 'tok')).called(1);
      verify(tracking.disconnect()).called(greaterThanOrEqualTo(1));
      model.dispose();
    });
  });

  group('ruta por calles del back', () {
    const home = {'latitude': -27.3700, 'longitude': -55.9000};
    const ruta = {
      'provider': 'osrm',
      'distanceMeters': 1500,
      'durationSeconds': 300,
      'points': [
        {'lat': -27.3600, 'lng': -55.8900},
        {'lat': -27.3650, 'lng': -55.8950},
        {'lat': -27.3700, 'lng': -55.9000},
      ],
    };

    Future<OrderTrackingViewModel> abrirSinFabrica(String status) async {
      server = {'status': status, 'delivery_address': home};
      final model = OrderTrackingViewModel(
        orderId: 'o1',
        pollInterval: const Duration(hours: 1),
        iconLoader: () async => null,
      );
      await model.initialize();
      return model;
    }

    test('en camino pide GET /routes/driving?orderId= al back y la dibuja',
        () async {
      final log = fakeHttp((_) => const FakeReply(200, ruta));
      final model = await abrirSinFabrica('out_for_delivery');

      locations.add(
          const DriverLocationUpdate(lat: -27.36, lng: -55.89, heading: 0));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(log, hasLength(1));
      expect(log.single.method, 'GET');
      expect(log.single.path, 'routes/driving?orderId=o1');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      final line = model.polylines.single;
      expect(line.points.length, 3);
      expect(line.patterns, isEmpty);
      model.dispose();
    });

    test('con 429 del back dibuja la recta punteada, sin cartel de error',
        () async {
      fakeHttp((_) => const FakeReply(429, {'message': 'Too Many Requests'}));
      final model = await abrirSinFabrica('out_for_delivery');

      locations.add(
          const DriverLocationUpdate(lat: -27.36, lng: -55.89, heading: 0));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(model.polylines.single.patterns, isNotEmpty);
      expect(model.loadError, isNull);
      verifyNever((locator<DialogService>() as MockDialogService).showDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        buttonTitle: anyNamed('buttonTitle'),
      ));
      model.dispose();
    });

    test('con el pedido aceptado ni pregunta al back', () async {
      final log = fakeHttp((_) => const FakeReply(200, ruta));
      final model = await abrirSinFabrica('accepted');

      locations.add(
          const DriverLocationUpdate(lat: -27.36, lng: -55.89, heading: 0));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(log, isEmpty);
      model.dispose();
    });
  });

  group('sondeo tras Reintentar', () {
    test('una primera carga fallida y Reintentar dejan el sondeo andando',
        () async {
      var fail = true;
      var calls = 0;
      when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async {
        calls++;
        return fail ? null : {'status': 'pending'};
      });
      final model = vm(poll: const Duration(milliseconds: 40));
      await model.initialize();
      fail = false;
      await model.retry();
      final before = calls;

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(calls - before, greaterThan(1));
      model.dispose();
    });

    test(
        'Reintentar antes de que termine initialize no duplica ni mata el '
        'sondeo', () async {
      var calls = 0;
      when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return {'status': 'pending'};
      });
      final model = vm(poll: const Duration(milliseconds: 50));
      final init = model.initialize();
      final retry = model.retry();
      await Future.wait([init, retry]);
      final before = calls;

      await Future<void>.delayed(const Duration(milliseconds: 330));

      // Un solo timer de 50 ms: unas 6 consultas, no el doble.
      expect(calls - before, inInclusiveRange(3, 8));
      model.dispose();
    });
  });

  group('hora de la posición (reloj del servidor)', () {
    String hace(int s) =>
        DateTime.now().toUtc().subtract(Duration(seconds: s)).toIso8601String();

    test(
        'la posición del pedido, más nueva que la del socket, gana aunque la '
        'del socket sea de "ahora" en el teléfono', () async {
      final model = await abrir({
        'status': 'out_for_delivery',
        'driver': driver(location: null),
      });
      // El socket trae su propia hora (servidor): hace 60 s.
      locations.add(DriverLocationUpdate(
          lat: -27.30,
          lng: -55.80,
          heading: 0,
          at: DateTime.now().subtract(const Duration(seconds: 60))));
      await pump();

      server = {
        'status': 'out_for_delivery',
        'driver': driver(location: {
          'lat': -27.31,
          'lng': -55.81,
          'at': hace(20),
        }),
      };
      await model.poll();

      expect(model.driverPosition, const LatLng(-27.31, -55.81));
      model.dispose();
    });

    test('una location con at null no se descarta entera', () async {
      final model = await abrir({
        'status': 'out_for_delivery',
        'driver': driver(location: {'lat': -27.36, 'lng': -55.89, 'at': null}),
      });

      expect(model.driverPosition, const LatLng(-27.36, -55.89));
      model.dispose();
    });
  });
}
