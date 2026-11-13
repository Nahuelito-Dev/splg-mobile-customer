import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_payments.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/transfer_receipt_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/maps/route_service.dart';
import 'package:splg_lib/maps/route_tracker.dart';

import '../helpers/fake_transfer_receipt_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

/// El back agrupa en `payment_method: online` todo lo que no es efectivo y
/// manda el medio real en `paymentMethodDetail`: un pedido de Mercado Pago no
/// es una transferencia (ni en la lista, ni en el detalle, ni en el seguimiento).
Map<String, dynamic> pedidoDelBack(String? detail,
        {String method = 'online', String id = 'o1'}) =>
    {
      'id': id,
      'status': 'pending',
      'payment_method': method,
      if (detail != null) 'paymentMethodDetail': detail,
      'paymentStatus': 'pending',
      'totalAmount': 1000,
      'items': [
        {
          'quantity': 1,
          'unitPrice': 1000,
          'gasCylinder': {'id': 'g1', 'type': 'butano', 'weight': '10'},
        }
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(OrderPayments.clear);

  group('lectura del medio de pago', () {
    test('online + mercadopago se lee como Mercado Pago', () {
      final o = OrderApiMapper.parseOrder(pedidoDelBack('mercadopago'))!;
      expect(o.paymentMethod, PaymentMethod.mercadoPago);
      expect(paymentLabel(o.paymentMethod), 'Mercado Pago');
    });

    test('online + transfer se lee como transferencia', () {
      final o = OrderApiMapper.parseOrder(pedidoDelBack('transfer'))!;
      expect(o.paymentMethod, PaymentMethod.online);
      expect(paymentLabel(o.paymentMethod), 'Transferencia');
    });

    test('en la lista de pedidos cada uno muestra su medio real', () {
      final orders = OrderApiMapper.parseOrders([
        pedidoDelBack('mercadopago'),
        pedidoDelBack('transfer', id: 'o2'),
        pedidoDelBack('cash', method: 'cash', id: 'o3'),
        pedidoDelBack('account', method: 'account', id: 'o4'),
        pedidoDelBack(null, id: 'o5'),
      ]);
      expect(orders.map(orderPaymentLabel), [
        'Mercado Pago',
        'Transferencia',
        'Efectivo',
        'Cuenta corriente',
        'Pago en línea',
      ]);
    });

    test('un pedido a cuenta corriente no se descarta ni se puede modificar',
        () {
      final o = OrderApiMapper.parseOrder(
          pedidoDelBack('account', method: 'account'))!;
      expect(orderPaymentLabel(o), 'Cuenta corriente');
      expect(orderSurchargeMethod(o), isNull);
      expect(canEditOrder(o, null), isFalse);
    });

    test(
        'una lectura posterior sin detalle no convierte Mercado Pago en '
        '«en línea»', () {
      OrderApiMapper.parseOrder(pedidoDelBack('mercadopago'))!;
      final tarde = OrderApiMapper.parseOrder(pedidoDelBack(null))!;
      expect(tarde.paymentMethod, PaymentMethod.mercadoPago);
      expect(orderPaymentLabel(tarde), 'Mercado Pago');
    });

    test('una lectura posterior sin detalle conserva la transferencia', () {
      OrderApiMapper.parseOrder(pedidoDelBack('transfer'))!;
      final tarde = OrderApiMapper.parseOrder(pedidoDelBack(null))!;
      expect(orderPaymentLabel(tarde), 'Transferencia');
    });

    test('en línea sin detalle no se afirma transferencia', () {
      final o = OrderApiMapper.parseOrder(pedidoDelBack(null))!;
      expect(orderPaymentLabel(o), 'Pago en línea');
      expect(orderSurchargeMethod(o), isNull);
      expect(canEditOrder(o, null), isFalse);
    });
  });

  group('seguimiento', () {
    late MockOrderTrackingService tracking;
    late FakeTransferReceiptService transfer;
    late Map<String, dynamic> server;

    setUp(() {
      registerServices();
      tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
      transfer =
          locator<TransferReceiptService>() as FakeTransferReceiptService;
      final customers = locator<CustomerService>() as MockCustomerService;
      when(customers.token).thenAnswer((_) async => 'tok');
      when(customers.customer).thenReturn(customerWith());
      when(tracking.driverUpdates)
          .thenAnswer((_) => const Stream<DriverInfo>.empty());
      when(tracking.orderStatusUpdates)
          .thenAnswer((_) => const Stream<String>.empty());
      when(tracking.driverLocationUpdates)
          .thenAnswer((_) => const Stream<DriverLocationUpdate>.empty());
      when(tracking.fetchDriverPhoto('o1', 'tok'))
          .thenAnswer((_) async => const DriverPhotoLookup());
      when(tracking.fetchOrderById('o1', 'tok'))
          .thenAnswer((_) async => server);
    });
    tearDown(() => locator.reset());

    Future<OrderTrackingViewModel> abrir() async {
      final model = OrderTrackingViewModel(
        orderId: 'o1',
        pollInterval: const Duration(hours: 1),
        routeTracker: (d) =>
            RouteTracker(service: SplgRouteService(), destination: d),
        iconLoader: () async => null,
        paymentStateLoader: (_, __) async => null,
      );
      await model.initialize();
      return model;
    }

    test(
        'un pedido de Mercado Pago no pide datos bancarios ni ofrece '
        'subir comprobante', () async {
      server = pedidoDelBack('mercadopago');
      final model = await abrir();

      expect(model.transferIsOnline, isFalse);
      expect(model.paymentStateLabel, isNull);
      expect(model.canPayByTransfer, isFalse);
      expect(model.showTransferCard, isFalse);
      expect(transfer.calls.where((c) => c.startsWith('bank:')), isEmpty);
      model.dispose();
    });

    for (final (nombre, detail, method) in [
      ('en línea sin detalle', null, 'online'),
      ('a cuenta corriente', 'account', 'account'),
    ]) {
      test('un pedido $nombre no pide datos bancarios ni ofrece comprobante',
          () async {
        server = pedidoDelBack(detail, method: method);
        final model = await abrir();

        expect(model.transferIsOnline, isFalse);
        expect(model.paymentStateLabel, isNull);
        expect(model.showTransferCard, isFalse);
        expect(transfer.calls.where((c) => c.startsWith('bank:')), isEmpty);
        model.dispose();
      });
    }

    test('un pedido por transferencia sí pide los datos bancarios', () async {
      server = pedidoDelBack('transfer');
      final model = await abrir();

      expect(model.transferIsOnline, isTrue);
      expect(model.paymentStateLabel, 'Pendiente de pago');
      expect(transfer.calls, contains('bank:o1'));
      model.dispose();
    });
  });
}
