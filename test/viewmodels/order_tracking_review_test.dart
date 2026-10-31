import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/maps/route_service.dart';
import 'package:splg_lib/maps/route_tracker.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderTrackingService tracking;
  late StreamController<String> statuses;
  late StreamController<DriverInfo> drivers;
  late StreamController<String> reasons;
  late StreamController<void> arrived;
  Map<String, dynamic>? server;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    statuses = StreamController<String>.broadcast();
    drivers = StreamController<DriverInfo>.broadcast();
    reasons = StreamController<String>.broadcast();
    arrived = StreamController<void>.broadcast();
    when(tracking.driverUpdates).thenAnswer((_) => drivers.stream);
    when(tracking.orderStatusUpdates).thenAnswer((_) => statuses.stream);
    when(tracking.cancellationReasons).thenAnswer((_) => reasons.stream);
    when(tracking.arrivedUpdates).thenAnswer((_) => arrived.stream);
    when(tracking.driverLocationUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup(url: 'https://x/f'));
    when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async => server);
    server = {'status': 'pending'};
  });

  tearDown(() {
    statuses.close();
    drivers.close();
    reasons.close();
    arrived.close();
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

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('un sondeo viejo no pisa lo que llegó por el socket', () {
    test('entregado por socket mientras un sondeo estaba en vuelo', () async {
      server = {'status': 'on_the_way'};
      final model = vm();
      await model.initialize();
      final slow = Completer<Map<String, dynamic>?>();
      when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) => slow.future);

      final sondeo = model.poll();
      await pump();
      statuses.add('delivered');
      await pump();
      slow.complete({'status': 'on_the_way'});
      await sondeo;

      expect(model.stage, TrackingStage.delivered);
      expect(model.canConfirmDelivery, isFalse);
      model.dispose();
    });

    test('un aviso de aceptado no lo pisa una respuesta anterior (pendiente)',
        () async {
      final model = vm();
      await model.initialize();
      final slow = Completer<Map<String, dynamic>?>();
      when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) => slow.future);

      final sondeo = model.poll();
      await pump();
      statuses.add('accepted');
      await pump();
      slow.complete({'status': 'pending'});
      await sondeo;

      expect(model.stage, TrackingStage.assigned);
      model.dispose();
    });

    test('el aviso de aceptado trae del pedido el chofer y su vehículo',
        () async {
      final model = vm();
      await model.initialize();
      final slow = Completer<Map<String, dynamic>?>();
      when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) => slow.future);

      final sondeo = model.poll();
      await pump();
      statuses.add('accepted');
      await pump();
      slow.complete({'status': 'pending'});
      await sondeo;
      server = {
        'status': 'accepted',
        'driver': {
          'userId': 'u1',
          'fullName': 'Ramón Villalba',
          'ratingAverage': 4.1,
          'ratingCount': 3,
        },
        'vehicle': {'patent': 'AF218KT', 'brand': 'Toyota', 'model': 'Hilux'},
      };
      when(tracking.fetchOrderById('o1', 'tok'))
          .thenAnswer((_) async => server);
      statuses.add('accepted');
      await pump();
      await pump();

      expect(model.driverRating, 4.1);
      expect(model.vehiclePlate, 'AF218KT');
      expect(model.vehicleName, 'Toyota Hilux');
      model.dispose();
    });

    test('una vez terminado, ninguna respuesta lo reabre', () async {
      server = {'status': 'delivered'};
      final model = vm();
      await model.initialize();
      server = {'status': 'on_the_way'};

      await model.retry();

      expect(model.stage, TrackingStage.delivered);
      model.dispose();
    });
  });

  test('un pedido que ya terminó al abrir no abre el socket', () async {
    server = {'status': 'delivered'};
    final model = vm();
    await model.initialize();

    verifyNever(tracking.subscribeToOrder(
      orderId: anyNamed('orderId'),
      customerId: anyNamed('customerId'),
      tokenProvider: anyNamed('tokenProvider'),
    ));
    model.dispose();
  });

  group('salir de la pantalla mientras carga', () {
    testWidgets('no quedan radar ni socket vivos', (t) async {
      final slow = Completer<Map<String, dynamic>?>();
      when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) => slow.future);
      final model = vm();
      unawaited(model.initialize());
      await t.pump();
      model.dispose();
      clearInteractions(tracking);

      slow.complete({'status': 'pending'});
      await t.pump();
      await t.pump(const Duration(seconds: 3));

      verifyNever(tracking.subscribeToOrder(
        orderId: anyNamed('orderId'),
        customerId: anyNamed('customerId'),
        tokenProvider: anyNamed('tokenProvider'),
      ));
      // Un radar vivo dejaría un Timer periódico pendiente y fallaría el test.
    });
  });

  group('segundo plano', () {
    testWidgets('en pausa corta sondeo, radar y socket; al volver relee',
        (t) async {
      final model = vm(poll: const Duration(seconds: 20));
      await model.initialize();
      clearInteractions(tracking);

      model.didChangeAppLifecycleState(AppLifecycleState.paused);
      verify(tracking.disconnect()).called(1);
      await t.pump(const Duration(minutes: 2));
      verifyNever(tracking.fetchOrderById(any, any));

      model.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump();
      await t.pump();

      verify(tracking.fetchOrderById('o1', 'tok')).called(1);
      verify(tracking.subscribeToOrder(
        orderId: 'o1',
        customerId: anyNamed('customerId'),
        tokenProvider: anyNamed('tokenProvider'),
      )).called(1);
      await t.pump(const Duration(seconds: 21));
      verify(tracking.fetchOrderById('o1', 'tok')).called(1);
      model.dispose();
    });

    testWidgets('en pausa no queda ningún timer periódico', (t) async {
      final model = vm(poll: const Duration(seconds: 20));
      await model.initialize(); // pendiente: hay radar y sondeo
      model.didChangeAppLifecycleState(AppLifecycleState.inactive);
      // Si quedara el radar o el sondeo, el test falla por Timer pendiente.
      model.dispose();
    });
  });

  group('reintentar tras una carga fallida', () {
    test('un pedido entregado cierra el seguimiento', () async {
      server = null;
      final model = vm();
      await model.initialize();
      expect(model.hasOrderLoaded, isFalse);
      clearInteractions(tracking);

      server = {'status': 'delivered'};
      await model.retry();

      expect(model.isDelivered, isTrue);
      verify(tracking.disconnect()).called(greaterThanOrEqualTo(1));
      model.dispose();
    });

    test('un pedido aceptado pide la foto del repartidor', () async {
      server = null;
      final model = vm();
      await model.initialize();
      clearInteractions(tracking);

      server = {'status': 'accepted', 'delivery_name': 'Ana Gomez'};
      await model.retry();

      verify(tracking.fetchDriverPhoto('o1', 'tok')).called(1);
      expect(model.driverAvatarUrl, 'https://x/f');
      model.dispose();
    });

    test('con la sesión vencida no se ofrece reintentar', () async {
      final customers = locator<CustomerService>() as MockCustomerService;
      when(customers.token).thenAnswer((_) async => null);
      final model = vm();
      await model.initialize();

      expect(model.loadError, isNotNull);
      expect(model.canRetryLoad, isFalse);
      model.dispose();
    });

    test('un error de red sí se puede reintentar', () async {
      server = null;
      final model = vm();
      await model.initialize();

      expect(model.canRetryLoad, isTrue);
      model.dispose();
    });
  });

  group('reasignación', () {
    test('no quedan el teléfono ni la patente del chofer anterior', () async {
      server = {
        'status': 'accepted',
        'delivery_id': 'a',
        'delivery_name': 'Chofer A',
        'vehicle': {'patent': 'AA111AA', 'brand': 'Fiat', 'model': 'Fiorino'},
      };
      final model = vm();
      await model.initialize();
      drivers.add(const DriverInfo(name: 'Chofer A', phone: '+5493764000001'));
      await pump();
      expect(model.hasDriverPhone, isTrue);

      // A libera el pedido y lo toma B (sin teléfono y sin vehículo cargados).
      server = {'status': 'pending'};
      statuses.add('pending');
      await pump();
      server = {
        'status': 'accepted',
        'delivery_id': 'b',
        'delivery_name': 'Chofer B'
      };
      drivers.add(const DriverInfo(name: 'Chofer B'));
      statuses.add('accepted');
      await pump();
      await model.poll();

      expect(model.driverName, 'Chofer B');
      expect(model.hasDriverPhone, isFalse);
      expect(model.vehiclePlate, isNull);
      expect(model.vehicleName, isNull);
      model.dispose();
    });

    test('un chofer distinto sin pasar por pendiente también se limpia',
        () async {
      server = {'status': 'accepted', 'delivery_id': 'a'};
      final model = vm();
      await model.initialize();
      drivers.add(const DriverInfo(name: 'Chofer A', phone: '+54911'));
      await pump();

      drivers.add(const DriverInfo(name: 'Chofer B'));
      await pump();

      expect(model.hasDriverPhone, isFalse);
      model.dispose();
    });

    test('el aviso de que se liberó el pedido vuelve a "buscando"', () async {
      server = {'status': 'accepted', 'delivery_id': 'a', 'delivery_name': 'A'};
      final model = vm();
      await model.initialize();

      statuses.add('pending'); // order:searching-driver
      await pump();

      expect(model.stage, TrackingStage.pending);
      expect(model.driverName, 'Repartidor');
      expect(model.canCancelOrder, isTrue);
      model.dispose();
    });
  });

  group('eventos del back', () {
    test('order:arrived pasa a "llegando" sin perder el QR', () async {
      server = {'status': 'out_for_delivery'};
      final model = vm();
      await model.initialize();
      expect(model.stage, TrackingStage.inProgress);

      arrived.add(null);
      await pump();

      expect(model.stage, TrackingStage.arriving);
      expect(model.canConfirmDelivery, isTrue);
      model.dispose();
    });

    test('el motivo de order:cancelled llega por el socket', () async {
      final model = vm();
      await model.initialize();

      reasons.add('Cancelado por admin');
      statuses.add('cancelled');
      await pump();

      expect(model.finishedDetail, 'Motivo: Cancelado por admin');
      expect(model.statusTitle, 'Pedido cancelado');
      model.dispose();
    });
  });

  group('contrato', () {
    test('no lee claves que el back no manda', () async {
      server = {
        'status': 'accepted',
        'driver_phone': '+54000',
        'delivery_phone': '+54000',
        'driver_rating': 5,
        'vehicle_plate': 'ZZ999ZZ',
        'eta_minutes': 3,
      };
      final model = vm();
      await model.initialize();

      expect(model.hasDriverPhone, isFalse);
      expect(model.driverRating, isNull);
      expect(model.vehiclePlate, isNull);
      expect(model.etaTitle, 'Calculando llegada...');
      model.dispose();
    });
  });
}
