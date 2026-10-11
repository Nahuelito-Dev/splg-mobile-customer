import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/views/cancel_order/cancel_order_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockHistoryService history;
  late MockNavigationService nav;

  setUp(() {
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    nav = locator<NavigationService>() as MockNavigationService;
  });
  tearDown(() => locator.reset());

  test('sin motivo no se puede confirmar', () {
    final m = CancelOrderViewModel(orderId: 'o1');
    expect(m.canSubmit, isFalse);
    m.select(kCancelReasons.first);
    expect(m.canSubmit, isTrue);
  });

  test('"Otro" pide el texto', () {
    final m = CancelOrderViewModel(orderId: 'o1')..select('Otro');
    expect(m.isOther, isTrue);
    expect(m.canSubmit, isFalse);
    m.other.text = 'Me mudé';
    expect(m.canSubmit, isTrue);
    expect(m.reasonText, 'Me mudé');
  });

  test('cancela con el motivo elegido y queda hecho', () async {
    when(history.cancelOrder('o1', reason: anyNamed('reason')))
        .thenAnswer((_) async => const CancelResult.ok());
    final m = CancelOrderViewModel(orderId: 'o1')..select('Pedí por error');

    await m.submit();

    verify(history.cancelOrder('o1', reason: 'Pedí por error')).called(1);
    expect(m.done, isTrue);
    expect(m.errorMessage, isNull);
    m.close();
    verify(nav.back(result: true)).called(1);
  });

  test('un rechazo del back muestra su mensaje y no queda hecho', () async {
    when(history.cancelOrder('o1', reason: anyNamed('reason'))).thenAnswer(
        (_) async => const CancelResult.rejected(
            'El pedido ya está en camino. Contacte al soporte.'));
    final m = CancelOrderViewModel(orderId: 'o1')..select('Otro');
    m.other.text = 'x';

    await m.submit();

    expect(m.done, isFalse);
    expect(m.errorMessage, 'El pedido ya está en camino. Contacte al soporte.');
    m.close();
    verify(nav.back(result: false)).called(1);
  });

  test('tras un fallo de red se puede reintentar', () async {
    var calls = 0;
    when(history.cancelOrder('o1', reason: anyNamed('reason')))
        .thenAnswer((_) async {
      calls++;
      return calls == 1 ? const CancelResult.failed() : const CancelResult.ok();
    });
    final m = CancelOrderViewModel(orderId: 'o1')..select(kCancelReasons.first);

    await m.submit();
    expect(m.errorMessage, isNotNull);
    expect(m.canSubmit, isTrue);
    await m.submit();

    expect(m.done, isTrue);
    expect(m.errorMessage, isNull);
    expect(calls, 2);
  });

  test('un segundo toque mientras cancela no duplica la llamada', () async {
    final pending = Future<CancelResult>.delayed(
        const Duration(milliseconds: 20), () => const CancelResult.ok());
    when(history.cancelOrder('o1', reason: anyNamed('reason')))
        .thenAnswer((_) => pending);
    final m = CancelOrderViewModel(orderId: 'o1')..select(kCancelReasons.first);

    final first = m.submit();
    await m.submit();
    await first;

    verify(history.cancelOrder('o1', reason: anyNamed('reason'))).called(1);
  });
}
