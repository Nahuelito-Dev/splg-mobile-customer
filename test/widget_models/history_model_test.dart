import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/ui/widgets/common/history/history_model.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

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

    group('cancelOrder -', () {
      Order pending() => Order(
            id: '1',
            total: 100,
            items: [],
            status: OrderStatus.pending,
            createdAt: DateTime.now(),
            paymentMethod: PaymentMethod.cash,
          );

      test('si el back rechaza, muestra SU mensaje (no "intentá de nuevo")',
          () async {
        final history = locator<HistoryService>() as MockHistoryService;
        final dialogs = locator<DialogService>() as MockDialogService;
        when(history.cancelOrder('1')).thenAnswer((_) async =>
            const CancelResult.rejected(
                'El pedido ya está en camino. Contacte al soporte.'));

        await HistoryModel().cancelOrder(pending());

        verify(dialogs.showDialog(
          title: 'No se pudo cancelar el pedido',
          description: 'El pedido ya está en camino. Contacte al soporte.',
        )).called(1);
      });

      test('ante un fallo de red/5xx invita a reintentar', () async {
        final history = locator<HistoryService>() as MockHistoryService;
        final dialogs = locator<DialogService>() as MockDialogService;
        when(history.cancelOrder('1'))
            .thenAnswer((_) async => const CancelResult.failed());

        await HistoryModel().cancelOrder(pending());

        verify(dialogs.showDialog(
          title: 'No se pudo cancelar el pedido',
          description:
              argThat(contains('Intentá nuevamente'), named: 'description'),
        )).called(1);
      });

      test('si cancela no muestra errores', () async {
        final history = locator<HistoryService>() as MockHistoryService;
        final dialogs = locator<DialogService>() as MockDialogService;
        when(history.cancelOrder('1'))
            .thenAnswer((_) async => const CancelResult.ok());

        await HistoryModel().cancelOrder(pending());

        verifyNever(dialogs.showDialog(
            title: anyNamed('title'), description: anyNamed('description')));
      });
    });
  });
}
