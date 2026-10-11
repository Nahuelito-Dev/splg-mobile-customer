import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  setUp(() => registerServices());
  tearDown(() => locator.reset());

  test('un doble toque en "Cancelar pedido" sólo manda una cancelación',
      () async {
    final history = locator<HistoryService>() as MockHistoryService;
    final pending = Completer<CancelResult>();
    when(history.cancelOrder('o1')).thenAnswer((_) => pending.future);
    final model = OrderTrackingViewModel(orderId: 'o1');

    final first = model.cancelOrder();
    expect(model.isBusy, isTrue);
    await model.cancelOrder();
    pending.complete(const CancelResult.ok());
    await first;

    verify(history.cancelOrder('o1')).called(1);
    expect(model.isBusy, isFalse);
  });
}
