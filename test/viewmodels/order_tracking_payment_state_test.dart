import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/domain/payment_state.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/maps/route_service.dart';
import 'package:splg_lib/maps/route_tracker.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_mercado_pago_checkout_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

/// El seguimiento muestra el estado del pago de Mercado Pago que informa el
/// back (texto, reintento y enlace): la app no arma el texto ni decide el estado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderTrackingService tracking;
  late FakeMercadoPagoCheckoutService mp;
  late MockDialogService dialogs;
  late StreamController<DriverInfo> drivers;
  late StreamController<String> statuses;
  late StreamController<DriverLocationUpdate> locations;
  late Map<String, dynamic> server;
  late PaymentState? backState;
  late List<String> asked;

  const rejected = PaymentState(
    status: 'rejected',
    detail: 'cc_rejected_insufficient_amount',
    label: 'Fondos insuficientes en el medio de pago',
    canRetry: true,
    paymentUrl: 'https://mp.test/checkout/1',
  );

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    mp =
        locator<MercadoPagoCheckoutService>() as FakeMercadoPagoCheckoutService;
    dialogs = locator<DialogService>() as MockDialogService;
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
    server = {
      'status': 'pending',
      'paymentStatus': 'failed',
      'paymentMethodDetail': 'mercadopago',
    };
    when(tracking.fetchOrderById('o1', 'tok')).thenAnswer((_) async => server);
    backState = rejected;
    asked = [];
  });

  tearDown(() {
    drivers.close();
    statuses.close();
    locations.close();
    locator.reset();
  });

  Future<OrderTrackingViewModel> abrir() async {
    final model = OrderTrackingViewModel(
      orderId: 'o1',
      pollInterval: const Duration(hours: 1),
      routeTracker: (d) =>
          RouteTracker(service: SplgRouteService(), destination: d),
      iconLoader: () async => null,
      paymentStateLoader: (orderId, token) async {
        asked.add('$orderId/$token');
        return backState;
      },
    );
    await model.initialize();
    return model;
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('estado del pago de Mercado Pago', () {
    test('muestra el texto que arma el back, sin reinterpretarlo', () async {
      final model = await abrir();

      expect(
          model.mercadoPagoLabel, 'Fondos insuficientes en el medio de pago');
      expect(asked, ['o1/tok']);
      model.dispose();
    });

    test(
        'con el pago rechazado ofrece «Reintentar pago» con el enlace del back',
        () async {
      final model = await abrir();

      expect(model.canPayWithMercadoPago, isTrue);
      expect(model.payButtonTitle, 'Reintentar pago');
      await model.payWithMercadoPago();
      expect(mp.opened, ['https://mp.test/checkout/1']);
      model.dispose();
    });

    test(
        'sin intento todavía (pendiente) el botón dice «Pagar con Mercado Pago»',
        () async {
      backState = const PaymentState(
        status: 'pending',
        label: 'Esperando el pago',
        canRetry: true,
        paymentUrl: 'https://mp.test/checkout/1',
      );
      final model = await abrir();

      expect(model.payButtonTitle, 'Pagar con Mercado Pago');
      expect(model.mercadoPagoLabel, 'Esperando el pago');
      model.dispose();
    });

    test('si el back dice que no se puede (pago en curso) no hay botón',
        () async {
      backState = const PaymentState(
        status: 'in_process',
        label: 'Pago en revisión',
        canRetry: false,
        paymentUrl: null,
      );
      final model = await abrir();

      expect(model.mercadoPagoLabel, 'Pago en revisión');
      expect(model.canPayWithMercadoPago, isFalse);
      await model.payWithMercadoPago();
      expect(mp.opened, isEmpty);
      model.dispose();
    });

    test('un pedido en efectivo no consulta el estado del pago', () async {
      server = {
        'status': 'pending',
        'paymentStatus': 'pending',
        'paymentMethodDetail': 'cash',
      };
      final model = await abrir();

      expect(asked, isEmpty);
      expect(model.mercadoPagoLabel, isNull);
      expect(model.canPayWithMercadoPago, isFalse);
      model.dispose();
    });

    test('pagado: se deja de consultar y no se ofrece pagar', () async {
      final model = await abrir();
      server = {
        'status': 'pending',
        'paymentStatus': 'paid',
        'paymentMethodDetail': 'mercadopago',
      };
      asked.clear();

      await model.poll();

      expect(asked, isEmpty);
      expect(model.mercadoPagoLabel, isNull);
      expect(model.canPayWithMercadoPago, isFalse);
      model.dispose();
    });

    test('pedido cancelado: no se ofrece pagar', () async {
      server = {
        'status': 'cancelled',
        'paymentStatus': 'failed',
        'paymentMethodDetail': 'mercadopago',
      };
      final model = await abrir();

      expect(model.canPayWithMercadoPago, isFalse);
      expect(model.mercadoPagoLabel, isNull);
      model.dispose();
    });

    test('si la consulta falla conserva lo último que se supo', () async {
      final model = await abrir();
      backState = null;

      await model.poll();

      expect(
          model.mercadoPagoLabel, 'Fondos insuficientes en el medio de pago');
      model.dispose();
    });

    test('cada lectura del pedido refresca el estado (rechazado → en revisión)',
        () async {
      final model = await abrir();
      backState = const PaymentState(
        status: 'in_process',
        label: 'Pago en revisión',
      );

      await model.poll();

      expect(model.mercadoPagoLabel, 'Pago en revisión');
      expect(model.canPayWithMercadoPago, isFalse);
      model.dispose();
    });

    test('si no se puede abrir Mercado Pago avisa', () async {
      mp.canOpen = false;
      final model = await abrir();

      await model.payWithMercadoPago();

      verify(dialogs.showDialog(
        title: 'No se pudo abrir el pago',
        description: anyNamed('description'),
        buttonTitle: 'Aceptar',
      )).called(1);
      model.dispose();
    });

    test(
        'al volver de un pago rechazado el aviso trae el motivo del back y dice que se puede reintentar',
        () async {
      final model = await abrir();

      mp.comeBack(const PaymentReturn(PaymentOutcome.failure, orderId: 'o1'));
      await pump();
      await pump();

      final captured = verify(dialogs.showDialog(
        title: 'El pago no se completó',
        description: captureAnyNamed('description'),
        buttonTitle: 'Aceptar',
      )).captured.single as String;
      expect(captured, contains('Fondos insuficientes en el medio de pago'));
      expect(captured, contains('reintentar'));
      model.dispose();
    });
  });

  group('B-9: el aviso al volver lo decide el back, no el deep link', () {
    void verifyShown(String title) => verify(dialogs.showDialog(
          title: title,
          description: anyNamed('description'),
          buttonTitle: 'Aceptar',
        )).called(1);

    test(
        'el link dice «éxito» pero el back dice que el pago fue rechazado: no se confirma nada',
        () async {
      final model = await abrir();

      mp.comeBack(const PaymentReturn(PaymentOutcome.success, orderId: 'o1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyShown('El pago no se completó');
      verifyNever(dialogs.showDialog(
          title: 'Estamos confirmando tu pago',
          description: anyNamed('description'),
          buttonTitle: anyNamed('buttonTitle')));
      model.dispose();
    });

    test(
        'el link dice «error» pero el back dice que el pago está en revisión: pendiente',
        () async {
      backState = const PaymentState(
        status: 'in_process',
        label: 'Pago en revisión',
      );
      final model = await abrir();

      mp.comeBack(const PaymentReturn(PaymentOutcome.failure, orderId: 'o1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyShown('Pago pendiente');
      model.dispose();
    });

    test(
        'si el back todavía no dice nada del pago, el link es el último recurso',
        () async {
      backState = null;
      final model = await abrir();

      mp.comeBack(const PaymentReturn(PaymentOutcome.failure, orderId: 'o1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyShown('El pago no se completó');
      model.dispose();
    });

    test('una reserva con la seña paga: «Pago realizado» y sin botón de pagar',
        () async {
      server = {
        'status': 'reserved',
        'paymentStatus': 'pending',
        'depositPaid': true,
        'paymentMethodDetail': 'mercadopago',
      };
      final model = await abrir();

      expect(model.canPayWithMercadoPago, isFalse);
      expect(model.mercadoPagoLabel, isNull);
      mp.comeBack(const PaymentReturn(PaymentOutcome.pending, orderId: 'o1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyShown('Pago realizado');
      model.dispose();
    });
  });
}
