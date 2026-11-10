import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/rating_service.dart';
import 'package:splg_customer/ui/common/live_notice.dart';
import 'package:splg_lib/domain/order.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late HistoryService history;

  setUp(() {
    registerServices();
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    history = HistoryService();
  });
  tearDown(() => locator.reset());

  final pedido = order(address: addr('a1', 'Mitre 100'))
      .copyWith(requestedDeliveryDate: DateTime(2026, 11, 3));

  test('la cotización de una reserva manda isReservation, seña y fecha',
      () async {
    final log = fakeHttp((_) => const FakeReply(200, {
          'items': [], 'subtotal': 1000, 'deposit': 300,
          'total': 1000, 'balance': 700,
        }));
    final o = await history.quoteOrder(pedido,
        fromCart: true, isReservation: true, depositAmount: 300);
    final body = log.single.body as Map;
    expect(body['isReservation'], isTrue);
    expect(body['depositAmount'], 300);
    expect(body['scheduledDate'], '2026-11-03');
    expect(o.quote!.deposit, 300);
    expect(o.quote!.balance, 700);
  });

  test('un pedido común no manda campos de reserva', () async {
    final log = fakeHttp((_) => const FakeReply(200, {'total': 1000}));
    await history.quoteOrder(pedido, fromCart: true);
    final body = log.single.body as Map;
    expect(body.containsKey('isReservation'), isFalse);
    expect(body.containsKey('depositAmount'), isFalse);
  });

  test('el alta de la reserva manda la seña y el 400 del back llega con su texto',
      () async {
    final log = fakeHttp((_) => const FakeReply(400, {
          'statusCode': 400,
          'message': 'La seña (\$2000.00) no puede superar el total del pedido (\$1000.00)',
        }));
    final r = await history.createOrder(pedido,
        fromCart: true, isReservation: true, depositAmount: 2000);
    expect((log.single.body as Map)['depositAmount'], 2000);
    expect(r.success, isFalse);
    expect(r.message, contains('no puede superar'));
  });

  test('express: vista previa y compra con su clave de idempotencia', () async {
    final log = fakeHttp((req) => req.path.endsWith('quote')
        ? const FakeReply(200, {
            'available': true,
            'address': {'street': 'Mitre 1', 'city': 'Posadas'},
            'item': {'gasCylinderId': 'g1', 'quantity': 1},
            'quote': {'total': 1500, 'items': []},
          })
        : const FakeReply(201, {
            'order_id': 'e1', 'total_amount': 1500, 'status': 'pending',
            'created_at': '2026-10-10T10:00:00Z',
          }));
    final p = await history.expressPreview(paymentMethod: PaymentMethod.cash);
    expect(p.ok, isTrue);
    expect(log.first.path, 'orders/express/quote');
    final r = await history.expressBuy(
        paymentMethod: PaymentMethod.cash, gasCylinderId: 'g1');
    expect(log.last.path, 'orders/express');
    expect((log.last.body as Map)['gasCylinderId'], 'g1');
    expect(r.success, isTrue);
    expect(r.order!.id, 'e1');
  });

  test('express no disponible (409) trae el motivo', () async {
    fakeHttp((_) => const FakeReply(409, {
          'code': 'EXPRESS_NOT_AVAILABLE', 'reason': 'out_of_hours',
          'message': 'x',
        }));
    final r = await history.expressBuy(paymentMethod: PaymentMethod.cash);
    expect(r.success, isFalse);
    expect(r.expressUnavailableReason, 'out_of_hours');
  });

  test('historial de estados: lista; un error vuelve con su código', () async {
    fakeHttp((_) => const FakeReply(200, [
          {'toStatus': 'pending', 'isNote': false,
           'changedAt': '2026-10-10T10:00:00Z'}
        ]));
    expect((await history.fetchStatusHistory('o1')).data, hasLength(1));
    fakeHttp((_) => const FakeReply(500, {'message': 'x'}));
    final e500 = await history.fetchStatusHistory('o1');
    expect(e500.ok, isFalse);
    expect(e500.status, 500);
    expect(e500.message, isNotEmpty);
    fakeHttp((_) =>
        const FakeReply(404, {'message': 'Pedido no encontrado'}));
    expect((await history.fetchStatusHistory('o1')).status, 404);
  });

  test('calificación del chofer: promedio; un error vuelve con su texto y código',
      () async {
    final log = fakeHttp((_) => const FakeReply(200, {
          'average': 4.5, 'count': 2,
        }));
    final ratings = RatingService();
    final ok = await ratings.summaryOf('u9');
    expect(log.single.path, 'ratings/user/u9/summary');
    expect(ok.ok, isTrue);
    expect(ok.data!.count, 2);
    fakeHttp((_) => const FakeReply(503, {
          'statusCode': 503, 'message': 'El servicio no responde.',
        }));
    final e503 = await ratings.summaryOf('u9');
    expect(e503.ok, isFalse);
    expect(e503.status, 503);
    expect(e503.message, isNotEmpty);
    fakeHttp((_) => const FakeReply(403, {
          'statusCode': 403, 'message': 'No tenés permiso para hacer esto.',
        }));
    final e403 = await ratings.summaryOf('u9');
    expect(e403.status, 403);
    expect(e403.message, 'No tenés permiso para hacer esto.');
    fakeHttp((_) => const FakeReply.networkError());
    final offline = await ratings.summaryOf('u9');
    expect(offline.ok, isFalse);
    expect(offline.message, isNotEmpty);
  });

  group('avisos en vivo', () {
    test('pago aprobado de seña, reintegro y pedido modificado', () async {
      final s = OrderTrackingService();
      final out = <OrderLiveEvent>[];
      s.liveEvents.listen(out.add);
      s.onPaymentApproved({'orderId': 'o1', 'tipo': 'deposit'});
      s.onPaymentRefunded({'orderId': 'o1', 'amount': 500});
      s.onOrderUpdated(
          {'orderId': 'o1', 'totalAmount': 1200, 'previousTotalAmount': 1000});
      await Future<void>.delayed(Duration.zero);
      expect(out.map((e) => e.kind), [
        OrderLiveEventKind.paymentApproved,
        OrderLiveEventKind.paymentRefunded,
        OrderLiveEventKind.updated,
      ]);
      expect(out[0].isDeposit, isTrue);
      expect(out[0].notice, contains('seña'));
      expect(out[1].notice, 'Te devolvimos \$500.');
      expect(out[2].notice, contains('\$1.000'));
      expect(out[2].notice, contains('\$1.200'));
    });

    test('ignora avisos de otro pedido', () async {
      final s = OrderTrackingService();
      var live = 0;
      var changes = 0;
      s.liveEvents.listen((_) => live++);
      s.orderChanges.listen((_) => changes++);
      s.subscribeToOrder(
          orderId: 'o1', customerId: 'c1', tokenProvider: () async => 'tok');
      s.onPaymentApproved({'orderId': 'otro'});
      s.onPaymentRefunded({'orderId': 'otro', 'amount': 1});
      s.onOrderUpdated({'orderId': 'otro', 'totalAmount': 1});
      await Future<void>.delayed(Duration.zero);
      expect(live, 0);
      expect(changes, 0);
      s.onPaymentApproved({'orderId': 'o1'});
      await Future<void>.delayed(Duration.zero);
      expect(live, 1);
      expect(changes, 1);
      s.disconnect();
    });
  });
}
