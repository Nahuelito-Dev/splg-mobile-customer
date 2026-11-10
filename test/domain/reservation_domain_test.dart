import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/domain/coverage_check.dart';
import 'package:splg_customer/domain/deposit_input.dart';
import 'package:splg_customer/domain/express_preview.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_status_entry.dart';
import 'package:splg_customer/domain/rating_summary.dart';
import 'package:splg_customer/domain/reserved_orders.dart';
import 'package:splg_lib/domain/order.dart';

import '../helpers/fixtures.dart';

void main() {
  tearDown(ReservedOrders.clear);

  group('DepositInput (mismas reglas que CreateOrderDto)', () {
    DepositInput p(String raw,
            {PaymentMethod m = PaymentMethod.cash, double? total}) =>
        DepositInput.parse(raw, method: m, total: total);

    test('vacío, no numérico y negativo se rechazan', () {
      expect(p('').error, contains('Indicá'));
      expect(p('abc').error, contains('válido'));
      expect(p('-5').error, contains('negativa'));
    });

    test('más de 2 decimales se rechaza; coma o punto valen', () {
      expect(p('10.123').error, contains('2 decimales'));
      expect(p('10,5').amount, 10.5);
      expect(p('10.25').amount, 10.25);
    });

    test('0 vale en efectivo pero no con Mercado Pago', () {
      expect(p('0').valid, isTrue);
      expect(p('0', m: PaymentMethod.mercadoPago).error, contains('mayor a cero'));
      expect(p('0.01', m: PaymentMethod.mercadoPago).valid, isTrue);
    });

    test('no puede superar el total; igual al total sí', () {
      expect(p('2001', total: 2000).error, contains('no puede superar'));
      expect(p('2000', total: 2000).valid, isTrue);
    });
  });

  group('reserva en el pedido', () {
    test('el mapper lee reserved como pendiente y deja el id marcado', () {
      final o = OrderApiMapper.parseOrder({
        'order_id': 'r1',
        'status': 'reserved',
        'total_amount': 100,
        'created_at': '2026-10-10T10:00:00Z',
      });
      expect(o!.status, OrderStatus.pending);
      expect(ReservedOrders.contains('r1'), isTrue);
      // Al activarse (pending) deja de figurar.
      OrderApiMapper.parseOrder({
        'order_id': 'r1',
        'status': 'pending',
        'total_amount': 100,
        'created_at': '2026-10-10T10:00:00Z',
      });
      expect(ReservedOrders.contains('r1'), isFalse);
    });

    test('el desglose lee seña, saldo y enlace; una reserva no se edita', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 1000,
        'status': 'reserved',
        'depositAmount': 300,
        'depositPaid': false,
        'remainingBalance': 1000,
        'payment_url': 'https://mp/x',
        'payment_method': 'online',
        'paymentMethodDetail': 'mercadopago',
        'driver': {'userId': 'u7'},
        'scheduledDate': '2026-11-01',
      })!;
      expect(b.isReservation, isTrue);
      expect(b.depositPending, isTrue);
      expect(b.paymentUrl, 'https://mp/x');
      expect(b.paysWithMercadoPago, isTrue);
      expect(b.driverUserId, 'u7');
      expect(canEditOrder(order(), b), isFalse);
      expect(canChangeOrderAddress(order(), b), isFalse);
    });

    test('seña paga: ya no hay nada que pagar', () {
      final b = OrderBreakdown.fromJson(
          {'total_amount': 1000, 'depositAmount': 300, 'depositPaid': true})!;
      expect(b.depositPending, isFalse);
    });
  });

  test('historial de estados: lee estados, notas y descarta lo ilegible', () {
    final l = OrderStatusEntry.listFromJson([
      {'fromStatus': null, 'toStatus': 'reserved', 'isNote': false,
       'changedAt': '2026-10-10T10:00:00Z'},
      {'toStatus': 'pending', 'isNote': true, 'reason': 'Cobro manual',
       'changedAt': '2026-10-11T10:00:00Z'},
      {'toStatus': 'x'},
    ]);
    expect(l, hasLength(2));
    expect(l.first.title, 'Reservado');
    expect(l.last.title, 'Nota');
    expect(l.last.reason, 'Cobro manual');
  });

  test('resumen de calificación', () {
    final s = RatingSummary.fromJson({'average': 4.5, 'count': 12})!;
    expect(s.label, '4,5 ★ · 12 calificaciones');
    expect(RatingSummary.fromJson({'average': 0, 'count': 0})!.label,
        'Todavía sin calificaciones');
    expect(RatingSummary.fromJson({'x': 1}), isNull);
  });

  test('cobertura: covered y zona', () {
    expect(CoverageCheck.fromJson({'covered': false})!.covered, isFalse);
    expect(
        CoverageCheck.fromJson({'covered': true, 'zone': {'name': 'Centro'}})!
            .zoneName,
        'Centro');
    expect(CoverageCheck.fromJson({}), isNull);
  });

  test('vista previa express: disponible con precio y no disponible con motivo',
      () {
    final ok = ExpressPreview.fromJson({
      'available': true,
      'address': {'street': 'Mitre 1', 'city': 'Posadas'},
      'item': {'gasCylinderId': 'g1', 'quantity': 1},
      'quote': {'total': 1500, 'items': []},
      'estimatedMinutes': 40,
    })!;
    expect(ok.available, isTrue);
    expect(ok.addressText, 'Mitre 1, Posadas');
    expect(ok.quote!.total, 1500);
    final no = ExpressPreview.fromJson({
      'available': false,
      'reason': 'out_of_hours',
      'quote': null,
    })!;
    expect(no.unavailableText, contains('fuera de horario'));
  });
}
