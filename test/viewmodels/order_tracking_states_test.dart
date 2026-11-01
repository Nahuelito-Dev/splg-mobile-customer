import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/tracking_routes.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/maps/route_service.dart';
import 'package:splg_lib/maps/route_tracker.dart';

import '../helpers/fake_mercado_pago_checkout_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

const _home = {'latitude': -27.3600, 'longitude': -55.8900};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderTrackingService tracking;
  late MockHistoryService history;
  late StreamController<DriverInfo> drivers;
  late StreamController<String> statuses;
  late StreamController<DriverLocationUpdate> locations;
  late Map<String, dynamic> server;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    history = locator<HistoryService>() as MockHistoryService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    drivers = StreamController<DriverInfo>.broadcast();
    statuses = StreamController<String>.broadcast();
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

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('estados finales', () {
    test('un pedido ya entregado no vuelve a "Buscando repartidor"', () async {
      server = {'status': 'delivered'};
      final model = await abrir();

      expect(model.stage, TrackingStage.delivered);
      expect(model.isDelivered, isTrue);
      expect(model.canCancelOrder, isFalse);
      expect(model.showRadar, isFalse);
      expect(model.statusTitle, 'Entregamos tu pedido');
      model.dispose();
    });

    test('un pedido cancelado muestra el motivo que informa el back', () async {
      server = {
        'status': 'cancelled',
        'cancellation_reason': 'Sin stock de garrafas',
      };
      final model = await abrir();

      expect(model.stage, TrackingStage.cancelled);
      expect(model.canCancelOrder, isFalse);
      expect(model.finishedDetail, 'Motivo: Sin stock de garrafas');
      model.dispose();
    });

    test('la entrega por socket cierra el seguimiento y corta el sondeo',
        () async {
      server = {'status': 'out_for_delivery'};
      final model = await abrir();
      clearInteractions(tracking);

      statuses.add('delivered');
      await pump();

      expect(model.stage, TrackingStage.delivered);
      expect(model.polylines, isEmpty);
      verify(tracking.disconnect()).called(1);
      model.dispose();
    });

    test('la cancelación por socket sin motivo lo lee del pedido', () async {
      server = {'status': 'pending'};
      final model = await abrir();

      server = {
        'status': 'cancelled',
        'cancellation_reason': 'Zona sin cobertura'
      };
      statuses.add('cancelled');
      await pump();
      await pump();

      expect(model.stage, TrackingStage.cancelled);
      expect(model.finishedDetail, 'Motivo: Zona sin cobertura');
      model.dispose();
    });

    test('con repartidor asignado no se puede cancelar', () async {
      server = {'status': 'accepted'};
      final model = await abrir();

      expect(model.canCancelOrder, isFalse);
      await model.cancelOrder();
      verifyNever(history.cancelOrder(any));
      model.dispose();
    });

    test('sólo pendiente permite cancelar', () async {
      final model = await abrir();
      expect(model.canCancelOrder, isTrue);
      model.dispose();
    });
  });

  group('sondeo de respaldo', () {
    testWidgets('si el socket no avisa, el sondeo trae el cambio de estado',
        (tester) async {
      final model = await abrir(poll: const Duration(seconds: 20));
      expect(model.stage, TrackingStage.pending);

      server = {'status': 'delivered'};
      await tester.pump(const Duration(seconds: 21));
      await tester.pump();

      expect(model.stage, TrackingStage.delivered);
      verify(tracking.disconnect()).called(greaterThanOrEqualTo(1));
      model.dispose();
    });

    testWidgets('al terminar deja de consultar', (tester) async {
      server = {'status': 'delivered'};
      final model = await abrir(poll: const Duration(seconds: 20));
      clearInteractions(tracking);

      await tester.pump(const Duration(seconds: 65));

      verifyNever(tracking.fetchOrderById(any, any));
      model.dispose();
    });
  });

  group('socket', () {
    test('se suscribe con un proveedor de token, no con un token fijo',
        () async {
      final customers = locator<CustomerService>() as MockCustomerService;
      var n = 0;
      when(customers.token).thenAnswer((_) async => 'tok-${++n}');
      when(tracking.fetchOrderById(any, any)).thenAnswer((_) async => server);
      final model = OrderTrackingViewModel(
        orderId: 'o1',
        pollInterval: const Duration(hours: 1),
        iconLoader: () async => null,
      );
      await model.initialize();

      final provider = verify(tracking.subscribeToOrder(
        orderId: 'o1',
        customerId: anyNamed('customerId'),
        tokenProvider: captureAnyNamed('tokenProvider'),
      )).captured.single as Future<String?> Function();
      final first = await provider();
      final second = await provider();

      expect(first, isNot(second));
      model.dispose();
    });
  });

  group('datos del repartidor', () {
    test('la patente sale de vehicle.patent del pedido', () async {
      server = {
        'status': 'accepted',
        'vehicle': {
          'carId': 'c1',
          'patent': 'AB123CD',
          'brand': 'Toyota',
          'model': 'Hilux',
        },
      };
      final model = await abrir();

      expect(model.vehiclePlate, 'AB123CD');
      expect(model.vehicleName, 'Toyota Hilux');
      model.dispose();
    });

    test('teléfono y calificación del bloque driver', () async {
      server = {
        'status': 'accepted',
        'driver': {
          'userId': 'd1',
          'fullName': 'Juan Pérez',
          'phoneNumber': '+54911',
          'ratingAverage': 4.8,
          'ratingCount': 12,
          'location': null,
        },
      };
      final model = await abrir();

      expect(model.driverName, 'Juan Pérez');
      expect(model.hasDriverPhone, isTrue);
      expect(model.driverRating, 4.8);
      model.dispose();
    });

    test('sin esos datos no inventa una patente', () async {
      server = {'status': 'accepted'};
      final model = await abrir();

      expect(model.vehiclePlate, isNull);
      expect(model.vehicleName, isNull);
      expect(model.hasDriverPhone, isFalse);
      model.dispose();
    });
  });

  group('foto del chofer', () {
    String firmada(DateTime emitida, int segundos) {
      String dos(int n) => n.toString().padLeft(2, '0');
      final u = emitida.toUtc();
      final fecha = '${u.year}${dos(u.month)}${dos(u.day)}T'
          '${dos(u.hour)}${dos(u.minute)}${dos(u.second)}Z';
      return 'https://s3/foto?X-Amz-Date=$fecha&X-Amz-Expires=$segundos&sig=1';
    }

    testWidgets('el evento usa el vencimiento de la propia URL, no 5 min fijos',
        (tester) async {
      server = {'status': 'accepted'};
      var llamadas = 0;
      when(tracking.fetchDriverPhoto('o1', 'tok')).thenAnswer((_) async {
        llamadas++;
        return const DriverPhotoLookup();
      });
      final model = await abrir();
      final base = llamadas;

      drivers.add(DriverInfo(
        photoUrl: firmada(DateTime.now(), 3600),
      ));
      await tester.pump();
      await tester.pump(const Duration(minutes: 10));

      // Una URL de 1 h no se renueva a los 5 minutos.
      expect(llamadas, base);

      await tester.pump(const Duration(minutes: 50));
      await tester.pump();
      expect(llamadas, base + 1);
      model.dispose();
    });
  });

  group('ruta por calles', () {
    const encoded = '_p~iO~ps|U_ulLnnqC_mqNvxq`@';

    test('el repartidor dibuja la ruta que devuelve el proveedor', () async {
      server = {
        'status': 'out_for_delivery',
        'delivery_address': _home,
      };
      final pedidos = <Uri>[];
      final model = await abrir(
        routeTracker: (d) => RouteTracker(
          destination: d,
          service: SplgRouteService(
            preferOsrm: true,
            release: false,
            fetch: (uri) async {
              pedidos.add(uri);
              return {
                'code': 'Ok',
                'routes': [
                  {'geometry': encoded, 'distance': 1000, 'duration': 600},
                ],
              };
            },
          ),
        ),
      );

      locations
          .add(const DriverLocationUpdate(lat: 38.5, lng: -120.2, heading: 0));
      await pump();
      await pump();
      await pump();

      expect(pedidos, hasLength(1));
      final line = model.polylines.single;
      expect(line.points.length, greaterThan(2));
      expect(line.patterns, isEmpty);
      expect(model.driverPosition, const LatLng(38.5, -120.2));
      model.dispose();
    });

    test('sin ruta por calles dibuja la recta punteada', () async {
      server = {
        'status': 'out_for_delivery',
        'delivery_address': _home,
      };
      final model = await abrir();

      locations.add(
          const DriverLocationUpdate(lat: -27.3500, lng: -55.8800, heading: 0));
      await pump();
      await pump();
      await pump();

      final line = model.polylines.single;
      expect(line.patterns, isNotEmpty);
      model.dispose();
    });

    test('con el pedido pendiente no hay ruta', () async {
      server = {'status': 'pending', 'delivery_address': _home};
      final model = await abrir();

      locations.add(
          const DriverLocationUpdate(lat: -27.3500, lng: -55.8800, heading: 0));
      await pump();

      expect(model.polylines, isEmpty);
      model.dispose();
    });
  });

  group('vuelta de Mercado Pago', () {
    late FakeMercadoPagoCheckoutService mp;
    late MockDialogService dialogs;

    setUp(() {
      mp = locator<MercadoPagoCheckoutService>()
          as FakeMercadoPagoCheckoutService;
      dialogs = locator<DialogService>() as MockDialogService;
    });

    void verifyShown(String title, {int times = 1}) =>
        verify(dialogs.showDialog(
          title: title,
          description: anyNamed('description'),
          buttonTitle: 'Aceptar',
        )).called(times);

    void verifyNothingShown() => verifyNever(dialogs.showDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        buttonTitle: anyNamed('buttonTitle')));

    test(
        'al volver con éxito relee el pedido y, si el back lo da por pagado, avisa',
        () async {
      final model = await abrir();
      clearInteractions(tracking);
      server = {'status': 'pending', 'paymentStatus': 'paid'};
      when(tracking.fetchOrderById('o1', 'tok'))
          .thenAnswer((_) async => server);

      mp.comeBack(const PaymentReturn(PaymentOutcome.success, orderId: 'o1'));
      await pump();
      await pump();

      verify(tracking.fetchOrderById('o1', 'tok')).called(greaterThan(0));
      verifyShown('Pago realizado');
      model.dispose();
    });

    test(
        'éxito sin external_reference y el back sin pago: no dice «Pago realizado»',
        () async {
      final model = await abrir();

      mp.comeBack(const PaymentReturn(PaymentOutcome.success));
      await pump();
      await pump();

      verifyShown('Estamos confirmando tu pago');
      verifyNever(dialogs.showDialog(
          title: 'Pago realizado',
          description: anyNamed('description'),
          buttonTitle: anyNamed('buttonTitle')));
      model.dispose();
    });

    test(
        'éxito sin external_reference pero el back lo da por pagado: lo dice el back',
        () async {
      final model = await abrir();
      server = {'status': 'pending', 'paymentStatus': 'paid'};
      when(tracking.fetchOrderById('o1', 'tok'))
          .thenAnswer((_) async => server);

      mp.comeBack(const PaymentReturn(PaymentOutcome.success));
      await pump();
      await pump();

      verifyShown('Pago realizado');
      model.dispose();
    });

    test(
        'un link de otro pedido no muestra ningún aviso en éste (ni «Pago realizado» ni «Estamos confirmando»), aunque éste figure pagado',
        () async {
      final model = await abrir();
      server = {'status': 'pending', 'paymentStatus': 'paid'};
      when(tracking.fetchOrderById('o1', 'tok'))
          .thenAnswer((_) async => server);
      clearInteractions(tracking);

      mp.comeBack(const PaymentReturn(PaymentOutcome.success, orderId: 'o2'));
      await pump();
      await pump();

      // Se relee este pedido, pero el aviso era de aquel otro.
      verify(tracking.fetchOrderById('o1', 'tok')).called(greaterThan(0));
      verifyNothingShown();
      model.dispose();
    });

    test('pendiente y error tienen su propio aviso', () async {
      final model = await abrir();

      mp.comeBack(const PaymentReturn(PaymentOutcome.pending));
      await pump();
      await pump();
      mp.comeBack(const PaymentReturn(PaymentOutcome.failure));
      await pump();
      await pump();

      verifyShown('Pago pendiente');
      verifyShown('El pago no se completó');
      model.dispose();
    });

    test(
        'arranque en frío: la vuelta pendiente se muestra al abrir el seguimiento',
        () async {
      mp.pending = const PaymentReturn(PaymentOutcome.pending, orderId: 'o1');

      final model = await abrir();
      await pump();
      await pump();

      verifyShown('Pago pendiente');
      expect(mp.pending, isNull);
      model.dispose();
    });

    test('la vuelta pendiente de otro pedido queda para ese pedido', () async {
      mp.pending = const PaymentReturn(PaymentOutcome.success, orderId: 'o2');

      final model = await abrir();
      await pump();

      verifyNothingShown();
      expect(mp.pending, isNotNull);
      model.dispose();
    });

    test('cerrado el seguimiento ya no escucha', () async {
      final model = await abrir();
      model.dispose();

      mp.comeBack(const PaymentReturn(PaymentOutcome.success));
      await pump();

      verifyNever(dialogs.showDialog(
          title: anyNamed('title'),
          description: anyNamed('description'),
          buttonTitle: anyNamed('buttonTitle')));
    });
  });
}
