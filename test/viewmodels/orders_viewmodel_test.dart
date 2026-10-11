import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/views/orders/orders_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

OrdersPage page(int from, int count, int total) => OrdersPage(
      orders: [for (var i = from; i < from + count; i++) order(id: 'o$i')],
      total: total,
      offset: from,
    );

void main() {
  late MockHistoryService history;

  setUp(() {
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    when(history.history).thenReturn(<Order>[]);
  });
  tearDown(() => locator.reset());

  test('carga la primera página y sabe que hay más', () async {
    when(history.fetchOrdersPage(limit: 20))
        .thenAnswer((_) async => page(0, 20, 29));
    final m = OrdersViewModel();
    await m.load();
    expect(m.orders, hasLength(20));
    expect(m.hasMore, isTrue);
  });

  test('cargar más pasa de 20 con el offset del back y no repite', () async {
    when(history.fetchOrdersPage(limit: 20))
        .thenAnswer((_) async => page(0, 20, 29));
    when(history.fetchOrdersPage(limit: 20, offset: 20))
        .thenAnswer((_) async => page(15, 14, 29)); // 5 repetidos + 9 nuevos
    final m = OrdersViewModel();
    await m.load();
    await m.loadMore();
    expect(m.orders, hasLength(29));
    expect(m.orders.map((o) => o.id).toSet(), hasLength(29));
    expect(m.hasMore, isFalse);
  });

  test('NO usa la lista del inicio: el polling no la trunca', () async {
    // El historial compartido (el del inicio) queda en 20; Mis pedidos no
    // debe leerlo ni reemplazarlo.
    when(history.history)
        .thenReturn([for (var i = 0; i < 20; i++) order(id: 'h$i')]);
    when(history.fetchOrdersPage(limit: 20))
        .thenAnswer((_) async => page(0, 20, 29));
    final m = OrdersViewModel();
    await m.load();
    verifyNever(history.refreshHistory(
        limit: anyNamed('limit'), offset: anyNamed('offset')));
    expect(m.orders.first.id, 'o0');
  });

  test('un error al cargar más conserva la lista y se reintenta a mano',
      () async {
    when(history.fetchOrdersPage(limit: 20))
        .thenAnswer((_) async => page(0, 20, 29));
    var calls = 0;
    when(history.fetchOrdersPage(limit: 20, offset: 20)).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('sin red');
      return page(20, 9, 29);
    });
    final m = OrdersViewModel();
    await m.load();
    await m.loadMore();
    expect(m.orders, hasLength(20));
    expect(m.moreError, isNotNull);
    await m.loadMore(); // por scroll: no se reintenta solo
    expect(calls, 1);
    await m.loadMore(retry: true);
    expect(m.orders, hasLength(29));
    expect(m.moreError, isNull);
  });

  test('un fallo en la primera carga es un error, no una lista vacía',
      () async {
    when(history.fetchOrdersPage(limit: 20)).thenThrow(Exception('sin red'));
    final m = OrdersViewModel();
    await m.load();
    expect(m.loadError, isNotNull);
  });

  test('un refresco fallido no pisa lo que ya había', () async {
    var fail = false;
    when(history.fetchOrdersPage(limit: 20)).thenAnswer((_) async {
      if (fail) throw Exception('sin red');
      return page(0, 5, 5);
    });
    final m = OrdersViewModel();
    await m.load();
    fail = true;
    await m.refresh();
    expect(m.orders, hasLength(5));
  });

  test('una respuesta de una época vieja se descarta', () async {
    when(history.fetchOrdersPage(limit: 20))
        .thenAnswer((_) async => page(0, 20, 40));
    final slow = Future<OrdersPage>.delayed(
        const Duration(milliseconds: 30), () => page(20, 20, 40));
    when(history.fetchOrdersPage(limit: 20, offset: 20))
        .thenAnswer((_) => slow);
    final m = OrdersViewModel();
    await m.load();
    final more = m.loadMore();
    await m.refresh(); // nueva época mientras el loadMore vuela
    await more;
    expect(m.orders, hasLength(20));
  });

  test('un refresco fallido con un loadMore en vuelo apaga el indicador',
      () async {
    var failRefresh = false;
    when(history.fetchOrdersPage(limit: 20)).thenAnswer((_) async {
      if (failRefresh) throw Exception('sin red');
      return page(0, 20, 40);
    });
    final slow = Future<OrdersPage>.delayed(
        const Duration(milliseconds: 30), () => page(20, 20, 40));
    when(history.fetchOrdersPage(limit: 20, offset: 20))
        .thenAnswer((_) => slow);
    final m = OrdersViewModel();
    await m.load();
    final more = m.loadMore();
    expect(m.loadingMore, isTrue);
    failRefresh = true;
    await m.refresh();
    await more;
    expect(m.loadingMore, isFalse);
    expect(m.orders, hasLength(20));
  });
}
