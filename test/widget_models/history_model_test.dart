import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/ui/widgets/common/history/history_model.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:mockito/mockito.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('HistoryModel Tests -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());

    test(
        'When repeatOrder is called, should set order in CartService and navigate to CheckoutView',
        () {
      final cartService = getAndRegisterCartService();
      final navigationService = getAndRegisterNavigationService();
      final model = HistoryModel();
      final order = Order(
        id: '1',
        total: 100,
        items: [],
        status: OrderStatus.delivered,
        createdAt: DateTime.now(),
        paymentMethod: PaymentMethod.cash,
      );

      model.repeatOrder(order);

      verify(cartService.setOrder(order));
      verify(navigationService.navigateToCheckoutView());
    });

    test(
        'When modifyOrder is called, should set order in CartService and navigate to CheckoutView',
        () {
      final cartService = getAndRegisterCartService();
      final navigationService = getAndRegisterNavigationService();
      final model = HistoryModel();
      final order = Order(
        id: '1',
        total: 100,
        items: [],
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        paymentMethod: PaymentMethod.cash,
      );

      model.modifyOrder(order);

      verify(cartService.setOrder(order));
      verify(navigationService.navigateToCheckoutView());
    });
  });
}
