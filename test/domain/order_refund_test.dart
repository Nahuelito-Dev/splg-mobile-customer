import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/order_refund.dart';

void main() {
  test('lee la forma que devuelve GET /orders/:id/refunds/mine', () {
    final list = OrderRefund.listFromJson([
      {
        'kind': 'full',
        'amount': 15800,
        'status': 'succeeded',
        'requestedAt': '2026-10-18T04:09:23.013Z',
        'completedAt': '2026-10-18T04:09:23.212Z',
      },
      {
        'kind': 'express_surcharge',
        'amount': '500.00',
        'status': 'pending',
        'requestedAt': '2026-10-18T04:09:23.013Z',
        'completedAt': null,
      },
    ]);

    expect(list, hasLength(2));
    expect(list[0].expressSurchargeOnly, isFalse);
    expect(list[0].amount, 15800);
    expect(list[0].status, RefundStatus.succeeded);
    expect(list[0].completedAt, isNotNull);
    expect(list[1].expressSurchargeOnly, isTrue);
    expect(list[1].amount, 500);
    expect(list[1].status, RefundStatus.pending);
    expect(list[1].completedAt, isNull);
  });

  test('lo ilegible se descarta y una respuesta que no es lista queda vacía',
      () {
    expect(
      OrderRefund.listFromJson([
        {'kind': 'full', 'amount': 10, 'status': 'rara'},
        {'kind': 'full', 'status': 'failed'},
        'basura',
        {'kind': 'full', 'amount': 10, 'status': 'failed'},
      ]),
      hasLength(1),
    );
    expect(OrderRefund.listFromJson(null), isEmpty);
    expect(OrderRefund.listFromJson({'a': 1}), isEmpty);
  });
}
