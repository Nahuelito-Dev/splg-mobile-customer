import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_refund.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/order_document_service.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockHistoryService history;
  late MockNavigationService nav;
  late MockCartService cart;
  OrderBreakdown? breakdown;

  setUpAll(() => initializeDateFormatting('es_AR', null));

  setUp(() {
    breakdown = null;
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    nav = locator<NavigationService>() as MockNavigationService;
    cart = locator<CartService>() as MockCartService;
  });
  tearDown(() => locator.reset());

  Future<OrderDetailViewModel> loaded(OrderStatus status) async {
    when(history.fetchOrderDetail('o1'))
        .thenAnswer((_) async => OrderDetail(order(status: status), breakdown));
    final m = OrderDetailViewModel(orderId: 'o1');
    await m.load();
    return m;
  }

  test('pendiente: cancelar y modificar, sin calificar ni reclamar', () async {
    final m = await loaded(OrderStatus.pending);
    expect((m.canCancel, m.canModify, m.canTrack, m.canRate, m.canClaim),
        (true, true, false, false, false));
    expect(m.canRepeat, isFalse);
  });

  test('en camino: seguimiento, sin cancelar', () async {
    final m = await loaded(OrderStatus.outForDelivery);
    expect((m.canTrack, m.canCancel, m.canRepeat), (true, false, false));
  });

  test('entregado: calificar, reclamar y repetir', () async {
    final m = await loaded(OrderStatus.delivered);
    expect((m.canRate, m.canClaim, m.canRepeat, m.canCancel),
        (true, true, true, false));
  });

  test('cancelado: sólo repetir', () async {
    final m = await loaded(OrderStatus.cancelled);
    expect((m.canRepeat, m.canRate, m.canClaim, m.canCancel),
        (true, false, false, false));
  });

  test('trae el pedido por id; si falla y no hay pedido, error', () async {
    when(history.fetchOrderDetail('zzz')).thenThrow(Exception('404'));
    final m = OrderDetailViewModel(orderId: 'zzz');
    await m.load();
    expect(m.loadError, isNotNull);
    expect(m.order, isNull);
  });

  test(
      'pedido que ya no existe (404/410): mensaje y sin Reintentar, aun con '
      'el de la lista a mano', () async {
    when(history.fetchOrderDetail('o1'))
        .thenAnswer((_) async => throw orderGoneFailure);
    final m = OrderDetailViewModel(
        orderId: 'o1', initial: order(status: OrderStatus.pending));

    await m.load();

    expect(m.loadError, kOrderGoneText);
    expect(m.canRetry, isFalse);
  });

  test('si desaparece al volver del seguimiento, se muestra el mensaje',
      () async {
    final m = await loaded(OrderStatus.accepted);
    when(history.fetchOrderDetail('o1'))
        .thenAnswer((_) async => throw orderGoneFailure);

    await m.track();

    expect(m.loadError, kOrderGoneText);
    expect(m.canRetry, isFalse);
    expect(m.order, isNull);
  });

  test('con el pedido de la lista a mano, un fallo de red no lo borra',
      () async {
    when(history.fetchOrderDetail('o1')).thenThrow(Exception('sin red'));
    final m = OrderDetailViewModel(
        orderId: 'o1', initial: order(status: OrderStatus.pending));
    await m.load();
    expect(m.loadError, isNull);
    expect(m.canCancel, isTrue);
  });

  test('repetir arma el carrito del back con los ítems y lo abre', () async {
    when(cart.replaceWith(any)).thenAnswer((_) async => const ApiResult.ok());
    final m = await loaded(OrderStatus.delivered);
    await m.repeat();
    final sent =
        verify(cart.replaceWith(captureAny)).captured.single as List<OrderItem>;
    expect(sent.single.cylinder.id, 'g1');
    verify(nav.navigateToCartView()).called(1);
    verifyNever(nav.navigateToCheckoutView());
  });

  test('si el back rechaza armar el carrito, avisa y no navega', () async {
    when(cart.replaceWith(any)).thenAnswer(
        (_) async => const ApiResult.fail('Sin conexión. Revisá tu internet.'));
    final m = await loaded(OrderStatus.delivered);
    await m.repeat();
    verify(locator<DialogService>().showDialog(
      title: 'No pudimos armar el carrito',
      description: 'Sin conexión. Revisá tu internet.',
      buttonTitle: 'Aceptar',
    )).called(1);
    verifyNever(nav.navigateToCartView());
  });

  group('modificar', () {
    test('abre la edición con el pedido y el desglose, y lo relee al volver',
        () async {
      breakdown = const OrderBreakdown(total: 1000, zoneSurcharge: 0);
      final m = await loaded(OrderStatus.pending);

      await m.modify();

      final args = verify(nav.navigateTo<dynamic>(Routes.editOrderView,
              arguments: captureAnyNamed('arguments'),
              id: anyNamed('id'),
              preventDuplicates: anyNamed('preventDuplicates'),
              parameters: anyNamed('parameters'),
              transition: anyNamed('transition')))
          .captured
          .single as EditOrderViewArguments;
      expect(args.order.id, 'o1');
      expect(args.breakdown, same(breakdown));
      verifyNever(nav.navigateToCheckoutView());
      verify(history.fetchOrderDetail('o1'))
          .called(2); // la carga y la relectura
    });

    test('si al volver lo tomó un repartidor, ya no se ofrece modificar',
        () async {
      final m = await loaded(OrderStatus.pending);
      expect(m.canModify, isTrue);
      when(history.fetchOrderDetail('o1')).thenAnswer((_) async =>
          OrderDetail(order(status: OrderStatus.accepted), breakdown));

      await m.modify();

      expect(m.canModify, isFalse);
      expect(m.canTrack, isTrue);
    });

    test('con repartidor asignado no se puede modificar aunque siga pendiente',
        () async {
      when(history.fetchOrderDetail('o1')).thenAnswer(
          (_) async => OrderDetail(order().copyWith(deliveryId: 'd1'), null));
      final m = OrderDetailViewModel(orderId: 'o1');
      await m.load();

      expect(m.canModify, isFalse);
      expect(m.canCancel, isTrue);
    });

    test('Mercado Pago no se puede modificar', () async {
      when(history.fetchOrderDetail('o1')).thenAnswer((_) async => OrderDetail(
          order().copyWith(paymentMethod: PaymentMethod.mercadoPago), null));
      final m = OrderDetailViewModel(orderId: 'o1');
      await m.load();

      expect(m.canModify, isFalse);
    });

    test('con el cobro ya pagado no se puede modificar', () async {
      breakdown = const OrderBreakdown(total: 1000, paymentStatus: 'paid');
      final m = await loaded(OrderStatus.pending);

      expect(m.canModify, isFalse);
    });
  });

  group('documentos PDF', () {
    test('el remito sale siempre; el recibo sólo con pago acreditado',
        () async {
      var m = await loaded(OrderStatus.pending);
      expect((m.canDownloadRemito, m.canDownloadRecibo), (true, false));

      breakdown = const OrderBreakdown(total: 1000, paymentStatus: 'pending');
      m = await loaded(OrderStatus.accepted);
      expect((m.canDownloadRemito, m.canDownloadRecibo), (true, false));

      breakdown = const OrderBreakdown(total: 1000, paymentStatus: 'paid');
      m = await loaded(OrderStatus.delivered);
      expect((m.canDownloadRemito, m.canDownloadRecibo), (true, true));
    });

    test('cancelado aunque figure pagado: remito sí, recibo no', () async {
      breakdown = const OrderBreakdown(total: 1000, paymentStatus: 'paid');
      final m = await loaded(OrderStatus.cancelled);
      expect((m.canDownloadRemito, m.canDownloadRecibo), (true, false));
    });

    test('mientras baja marca el documento y no lanza otra descarga', () async {
      final docs = locator<OrderDocumentService>() as MockOrderDocumentService;
      final gate = Completer<ApiResult<void>>();
      when(docs.open('o1', OrderDocument.remito))
          .thenAnswer((_) => gate.future);
      final m = await loaded(OrderStatus.pending);

      final first = m.openDocument(OrderDocument.remito);
      expect(m.downloading, OrderDocument.remito);
      await m.openDocument(OrderDocument.recibo);
      verifyNever(docs.open('o1', OrderDocument.recibo));

      gate.complete(const ApiResult.ok());
      await first;
      expect(m.downloading, isNull);
      verifyZeroInteractions(locator<DialogService>());
    });

    test('si el back rechaza, muestra su mensaje y libera el botón', () async {
      final docs = locator<OrderDocumentService>() as MockOrderDocumentService;
      when(docs.open('o1', OrderDocument.recibo)).thenAnswer((_) async =>
          const ApiResult.fail('El pedido está cancelado.', status: 409));
      final m = await loaded(OrderStatus.delivered);

      await m.openDocument(OrderDocument.recibo);

      expect(m.downloading, isNull);
      verify(locator<DialogService>().showDialog(
              title: 'No pudimos abrir el recibo',
              description: 'El pedido está cancelado.',
              buttonTitle: 'Aceptar'))
          .called(1);
    });
  });

  test('cancelar abre la pantalla de motivo y refresca si se canceló',
      () async {
    when(nav.navigateTo<dynamic>(Routes.cancelOrderView,
            arguments: anyNamed('arguments'),
            id: anyNamed('id'),
            preventDuplicates: anyNamed('preventDuplicates'),
            parameters: anyNamed('parameters'),
            transition: anyNamed('transition')))
        .thenAnswer((_) async => true);
    final m = await loaded(OrderStatus.pending);

    await m.cancel();

    verify(history.fetchOrderDetail('o1')).called(2); // la carga y el refresco
  });

  group('reintegro', () {
    OrderRefund refund(RefundStatus status,
            {bool express = false, double amount = 1500, DateTime? done}) =>
        OrderRefund(
            expressSurchargeOnly: express,
            amount: amount,
            status: status,
            completedAt: done);

    test('cancelado: lee el reintegro y lo muestra según su estado', () async {
      when(history.fetchOrderRefunds('o1')).thenAnswer((_) async => [
            refund(RefundStatus.pending),
            refund(RefundStatus.failed, express: true, amount: 500),
            refund(RefundStatus.succeeded, done: DateTime(2026, 10, 18)),
          ]);
      final m = await loaded(OrderStatus.cancelled);

      expect(m.refundRows, hasLength(3));
      expect(m.refundRows[0].title, 'Reintegro:');
      expect(m.refundRows[0].value, contains('en trámite'));
      expect(m.refundRows[1].title, 'Reintegro del recargo express:');
      expect(m.refundRows[1].value, contains('lo estamos revisando'));
      expect(m.refundRows[2].value, contains('acreditado el'));
      verify(history.fetchOrderRefunds('o1')).called(1);
    });

    test('express que pasó al reparto común: también lo busca', () async {
      breakdown = OrderBreakdown(
          total: 1,
          deliveryMode: DeliveryMode.standard,
          expressDegradedAt: DateTime(2026, 10, 18));
      when(history.fetchOrderRefunds('o1')).thenAnswer(
          (_) async => [refund(RefundStatus.pending, express: true)]);
      final m = await loaded(OrderStatus.pending);

      expect(m.refundRows, hasLength(1));
    });

    test('pedido común en curso: no consulta reintegros', () async {
      final m = await loaded(OrderStatus.pending);

      expect(m.refundRows, isEmpty);
      verifyNever(history.fetchOrderRefunds(any));
    });

    test('si no se pudo leer el reintegro, la pantalla carga igual sin él',
        () async {
      when(history.fetchOrderRefunds('o1')).thenAnswer((_) async => null);
      final m = await loaded(OrderStatus.cancelled);

      expect(m.order, isNotNull);
      expect(m.loadError, isNull);
      expect(m.refundRows, isEmpty);
    });
  });
}
