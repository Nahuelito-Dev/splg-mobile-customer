import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_status_entry.dart';
import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/domain/rating_summary.dart';
import 'package:splg_customer/domain/reserved_orders.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/rating_service.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_view.dart';
import 'package:splg_lib/splg_lib.dart';

import '../helpers/fake_mercado_pago_checkout_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void _phone(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (t) async {
    t.view.physicalSize = const Size(393, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await body(t);
  });
}

void main() {
  late MockHistoryService history;
  late MockRatingService ratings;
  late FakeMercadoPagoCheckoutService mp;
  OrderBreakdown? breakdown;

  setUpAll(() => initializeDateFormatting('es_AR', null));

  setUp(() {
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    ratings = locator<RatingService>() as MockRatingService;
    mp = locator<MercadoPagoCheckoutService>()
        as FakeMercadoPagoCheckoutService;
    final tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    when(tracking.liveEvents)
        .thenAnswer((_) => const Stream<OrderLiveEvent>.empty());
    when(tracking.orderChanges).thenAnswer((_) => const Stream<void>.empty());
    breakdown = const OrderBreakdown(total: 1000);
    when(history.fetchOrderDetail('o1')).thenAnswer(
        (_) async => OrderDetail(order(status: OrderStatus.pending), breakdown));
    when(history.fetchStatusHistory('o1'))
        .thenAnswer((_) async => const ApiResult.ok(<OrderStatusEntry>[]));
  });
  tearDown(() {
    ReservedOrders.clear();
    locator.reset();
  });

  _phone('historial con error: muestra el texto del back y se reintenta',
      (t) async {
    when(history.fetchStatusHistory('o1')).thenAnswer((_) async =>
        const ApiResult.fail('No tenés permiso para hacer esto.',
            status: 403));
    await t.pumpWidget(_app(const OrderDetailView(orderId: 'o1')));
    await _settle(t);
    expect(find.byKey(const Key('detail-timeline-error')), findsOneWidget);
    expect(find.textContaining('No tenés permiso para hacer esto.'),
        findsOneWidget);
    expect(find.byKey(const Key('detail-timeline')), findsNothing);

    when(history.fetchStatusHistory('o1')).thenAnswer((_) async =>
        ApiResult.ok([
          OrderStatusEntry(toStatus: 'pending', changedAt: DateTime(2026))
        ]));
    await t.tap(find.byKey(const Key('detail-extras-retry')));
    await _settle(t);
    expect(find.byKey(const Key('detail-timeline-error')), findsNothing);
    expect(find.byKey(const Key('detail-extras-retry')), findsNothing);
    expect(find.byKey(const Key('detail-timeline')), findsOneWidget);
  });

  _phone('calificación con error: muestra el texto del back y se reintenta',
      (t) async {
    breakdown = const OrderBreakdown(total: 1000, driverUserId: 'u9');
    when(ratings.summaryOf('u9')).thenAnswer((_) async =>
        const ApiResult.fail('El servicio no responde.', status: 503));
    // El pedido no trae el nombre del repartidor: el error igual se ve junto
    // al reintento (no queda un «Reintentar» sin explicación).
    await t.pumpWidget(_app(const OrderDetailView(orderId: 'o1')));
    await _settle(t);
    expect(find.byKey(const Key('detail-driver-rating-error')), findsOneWidget);
    expect(find.textContaining('El servicio no responde.'), findsOneWidget);
    expect(find.byKey(const Key('detail-extras-retry')), findsOneWidget);

    when(ratings.summaryOf('u9')).thenAnswer((_) async =>
        const ApiResult.ok(RatingSummary(average: 4.5, count: 2)));
    await t.tap(find.byKey(const Key('detail-extras-retry')));
    await _settle(t);
    expect(find.byKey(const Key('detail-driver-rating-error')), findsNothing);
    expect(find.byKey(const Key('detail-extras-retry')), findsNothing);
    verify(ratings.summaryOf('u9')).called(2);
  });

  _phone('pagar la seña: el botón se deshabilita mientras el checkout sigue '
      'abierto y un segundo toque no abre otro', (t) async {
    breakdown = const OrderBreakdown(
        total: 1000,
        reserved: true,
        depositAmount: 300,
        paymentMethodDetail: 'mercadopago',
        paymentUrl: 'https://mp/x');
    await t.pumpWidget(_app(const OrderDetailView(orderId: 'o1')));
    await _settle(t);
    final button = find.byKey(const Key('detail-pay-deposit'));
    expect(t.widget<SplgButton>(button).onPressed, isNotNull);

    await t.tap(button);
    await t.pump();
    expect(t.widget<SplgButton>(button).onPressed, isNull);
    await t.tap(button, warnIfMissed: false);
    await t.pump();
    expect(mp.opened, ['https://mp/x']);

    // Vuelve del checkout: se relee el pedido y se desbloquea.
    mp.comeBack(const PaymentReturn(PaymentOutcome.success, orderId: 'o1'));
    await _settle(t);
    expect(t.widget<SplgButton>(button).onPressed, isNotNull);
  });
}
