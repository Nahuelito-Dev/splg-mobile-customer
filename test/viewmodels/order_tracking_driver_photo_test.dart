import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderTrackingService tracking;
  late StreamController<DriverInfo> drivers;
  late StreamController<String> statuses;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    drivers = StreamController<DriverInfo>.broadcast();
    statuses = StreamController<String>.broadcast();
    when(tracking.driverUpdates).thenAnswer((_) => drivers.stream);
    when(tracking.orderStatusUpdates).thenAnswer((_) => statuses.stream);
    when(tracking.fetchOrderById('o1', 'tok'))
        .thenAnswer((_) async => {'status': 'accepted'});
  });

  tearDown(() {
    drivers.close();
    statuses.close();
    locator.reset();
  });

  Future<OrderTrackingViewModel> abrir({DriverPhotoLookup? lookup}) async {
    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => lookup ?? const DriverPhotoLookup());
    final model = OrderTrackingViewModel(orderId: 'o1');
    await model.initialize();
    return model;
  }

  test('el evento con photoUrl muestra la foto del chofer', () async {
    final model = await abrir();
    drivers.add(const DriverInfo(
        name: 'Juan Perez', phone: '1', photoUrl: 'https://s3/foto?sig=1'));
    await Future<void>.delayed(Duration.zero);

    expect(model.driverAvatarUrl, 'https://s3/foto?sig=1');
    expect(model.driverName, 'Juan Perez');
    model.dispose();
  });

  test('evento sin foto: pide la URL y, si no hay, queda con iniciales',
      () async {
    final model = await abrir();
    clearInteractions(tracking);
    drivers.add(const DriverInfo(name: 'Juan Perez'));
    await Future<void>.delayed(Duration.zero);

    verify(tracking.fetchDriverPhoto('o1', 'tok')).called(1);
    expect(model.driverAvatarUrl, isNull);
    expect(model.driverInitials, 'JP');
    model.dispose();
  });

  test('al abrir el seguimiento renueva la foto', () async {
    final model = await abrir(
      lookup: DriverPhotoLookup(
        url: 'https://s3/nueva',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    expect(model.driverAvatarUrl, 'https://s3/nueva');
    model.dispose();
  });

  testWidgets('renueva la foto 30 s antes de que venza', (tester) async {
    var llamadas = 0;
    when(tracking.fetchDriverPhoto('o1', 'tok')).thenAnswer((_) async {
      llamadas++;
      return DriverPhotoLookup(
        url: 'https://s3/foto$llamadas',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
    });
    final model = OrderTrackingViewModel(orderId: 'o1');
    await model.initialize();
    expect(model.driverAvatarUrl, 'https://s3/foto1');

    await tester.pump(const Duration(minutes: 4, seconds: 20));
    expect(llamadas, 1);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(llamadas, 2);
    expect(model.driverAvatarUrl, 'https://s3/foto2');
    model.dispose();
  });

  test('un 409/404 deja al chofer sin foto y sin error', () async {
    final model = await abrir();
    drivers.add(const DriverInfo(photoUrl: 'https://s3/foto'));
    await Future<void>.delayed(Duration.zero);
    expect(model.driverAvatarUrl, isNotNull);

    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup());
    await model.refreshDriverPhoto();

    expect(model.driverAvatarUrl, isNull);
    expect(model.hasError, isFalse);
    model.dispose();
  });

  test('un fallo de red no borra la foto que ya tenía', () async {
    final model = await abrir();
    drivers.add(const DriverInfo(photoUrl: 'https://s3/foto'));
    await Future<void>.delayed(Duration.zero);

    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup(failed: true));
    await model.refreshDriverPhoto();

    expect(model.driverAvatarUrl, 'https://s3/foto');
    model.dispose();
  });

  test('se limpia al entregar/cancelar y al salir del seguimiento', () async {
    final model = await abrir();
    drivers.add(const DriverInfo(photoUrl: 'https://s3/foto'));
    await Future<void>.delayed(Duration.zero);
    expect(model.driverAvatarUrl, isNotNull);

    statuses.add('cancelled');
    await Future<void>.delayed(Duration.zero);
    expect(model.driverAvatarUrl, isNull);

    drivers.add(const DriverInfo(photoUrl: 'https://s3/otra'));
    await Future<void>.delayed(Duration.zero);
    expect(model.driverAvatarUrl, 'https://s3/otra');
    model.dispose();
    expect(model.driverAvatarUrl, isNull);
  });
}
