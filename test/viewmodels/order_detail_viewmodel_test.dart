import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/history_service.dart';
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

  setUp(() {
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    nav = locator<NavigationService>() as MockNavigationService;
    cart = locator<CartService>() as MockCartService;
  });
  tearDown(() => locator.reset());

  Future<OrderDetailViewModel> loaded(OrderStatus status) async {
    when(history.fetchOrder('o1'))
        .thenAnswer((_) async => order(status: status));
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
    when(history.fetchOrder('zzz')).thenThrow(Exception('404'));
    final m = OrderDetailViewModel(orderId: 'zzz');
    await m.load();
    expect(m.loadError, isNotNull);
    expect(m.order, isNull);
  });

  test('con el pedido de la lista a mano, un fallo de red no lo borra',
      () async {
    when(history.fetchOrder('o1')).thenThrow(Exception('sin red'));
    final m = OrderDetailViewModel(
        orderId: 'o1', initial: order(status: OrderStatus.pending));
    await m.load();
    expect(m.loadError, isNull);
    expect(m.canCancel, isTrue);
  });

  test('repetir arma el carrito y abre la confirmación', () async {
    final m = await loaded(OrderStatus.delivered);
    m.repeat();
    verify(cart.setOrder(any)).called(1);
    verify(cart.clearEditingOrder()).called(1);
    verify(nav.navigateToCheckoutView()).called(1);
  });

  test('modificar marca el pedido como en edición', () async {
    final m = await loaded(OrderStatus.pending);
    m.modify();
    verify(cart.startEditingOrder('o1')).called(1);
    verify(nav.navigateToCheckoutView()).called(1);
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

    verify(history.fetchOrder('o1')).called(2); // la carga y el refresco
  });
}
