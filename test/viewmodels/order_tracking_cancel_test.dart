import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockNavigationService nav;

  setUp(() {
    registerServices();
    nav = locator<NavigationService>() as MockNavigationService;
  });
  tearDown(() => locator.reset());

  void stubCancelScreen(Future<dynamic> Function() answer) {
    when(nav.navigateTo<dynamic>(Routes.cancelOrderView,
            arguments: anyNamed('arguments'),
            id: anyNamed('id'),
            preventDuplicates: anyNamed('preventDuplicates'),
            parameters: anyNamed('parameters'),
            transition: anyNamed('transition')))
        .thenAnswer((_) => answer());
  }

  void verifyCancelScreen(int times) {
    verify(nav.navigateTo<dynamic>(Routes.cancelOrderView,
            arguments: anyNamed('arguments'),
            id: anyNamed('id'),
            preventDuplicates: anyNamed('preventDuplicates'),
            parameters: anyNamed('parameters'),
            transition: anyNamed('transition')))
        .called(times);
  }

  test(
      'cancelar abre la pantalla con motivo y confirmación, no cancela directo',
      () async {
    stubCancelScreen(() async => false);
    final history = locator<HistoryService>() as MockHistoryService;
    final model = OrderTrackingViewModel(orderId: 'o1');

    await model.cancelOrder();

    verifyCancelScreen(1);
    verifyNever(history.cancelOrder(any));
    verifyNever(nav.back());
  });

  test('si se canceló, cierra el seguimiento', () async {
    stubCancelScreen(() async => true);
    final model = OrderTrackingViewModel(orderId: 'o1');

    await model.cancelOrder();

    verify(nav.back()).called(1);
  });

  test('un doble toque no abre la pantalla dos veces', () async {
    var abierta = 0;
    stubCancelScreen(() async {
      abierta++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return false;
    });
    final model = OrderTrackingViewModel(orderId: 'o1');

    final first = model.cancelOrder();
    await model.cancelOrder();
    await first;

    expect(abierta, 1);
  });
}
