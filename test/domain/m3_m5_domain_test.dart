import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/cylinder_recovery.dart';
import 'package:splg_customer/domain/repurchase.dart';

import '../helpers/m3_m5_fixtures.dart';

void main() {
  group('RepurchaseInvitation', () {
    test('lee el pedido precargado, la dirección y la franja', () {
      final i = invitation();
      expect(i.invitationId, 'inv-1');
      expect(i.status, RepurchaseStatus.pending);
      expect(i.itemsLabel, '2 × 10kg · 1 × 15kg');
      expect(i.totalUnits, 3);
      expect(i.estimatedTotal, 31000);
      expect(i.addressLabel, 'Av. Corrientes 1234, Posadas');
      expect(i.slot!.label, 'Mañana · 09:00 a 13:00');
      expect(i.hasUnavailable, isFalse);
    });

    test('un ítem sin stock se marca y la invitación lo sabe', () {
      expect(invitation(available: false).hasUnavailable, isTrue);
    });

    test('sin franja ni dirección sigue siendo válida', () {
      final json = invitationJson(withSlot: false)..['address'] = null;
      final i = RepurchaseInvitation.fromJson(json)!;
      expect(i.slot, isNull);
      expect(i.addressLabel, isNull);
    });

    test('vigente sólo si está pendiente y no venció', () {
      final now = DateTime.now();
      expect(invitation().isOpenAt(now), isTrue);
      expect(
          invitation(expiresAt: now.subtract(const Duration(minutes: 1)))
              .isOpenAt(now),
          isFalse);
      final accepted =
          RepurchaseInvitation.fromJson(invitationJson(status: 'accepted'))!;
      expect(accepted.isOpenAt(now), isFalse);
    });

    test('un cuerpo sin id o sin vigencia no es una invitación', () {
      expect(RepurchaseInvitation.fromJson({'items': []}), isNull);
      expect(RepurchaseInvitation.fromJson(null), isNull);
    });
  });

  group('RepurchaseForecast', () {
    test('con fecha: días restantes, aviso e invitación abierta', () {
      final f = RepurchaseForecast.fromJson({
        'estimatedAt': '2026-11-10T12:00:00.000Z',
        'daysLeft': 10,
        'source': 'history',
        'reason': null,
        'notice': {
          'enabled': true,
          'days': null,
          'distributorDays': 3,
          'effectiveDays': 3
        },
        'openInvitation': invitationJson(),
      })!;
      expect(f.estimatedAt, isNotNull);
      expect(f.daysLeft, 10);
      expect(f.notice.usesDistributorDays, isTrue);
      expect(f.notice.effectiveDays, 3);
      expect(f.openInvitation!.invitationId, 'inv-1');
    });

    test('sin fecha explica el motivo', () {
      final f = RepurchaseForecast.fromJson({
        'estimatedAt': null,
        'daysLeft': null,
        'reason': 'insufficient_history',
        'notice': {'enabled': false, 'days': 5, 'effectiveDays': 5},
      })!;
      expect(f.estimatedAt, isNull);
      expect(f.reasonText, contains('pedidos suficientes'));
      expect(f.notice.enabled, isFalse);
      expect(f.notice.days, 5);
    });
  });

  group('RepurchaseAccepted', () {
    test('toma el pedido creado y el link de pago si hay', () {
      final a = RepurchaseAccepted.fromJson({
        'invitation': invitationJson(status: 'accepted'),
        'order': {'orderId': 'o9', 'paymentUrl': 'https://mp/pay'},
      })!;
      expect(a.orderId, 'o9');
      expect(a.paymentUrl, 'https://mp/pay');
    });

    test('sin pedido no hay aceptación', () {
      expect(RepurchaseAccepted.fromJson({'invitation': {}}), isNull);
    });
  });

  group('parseNoticeDays', () {
    test('acepta enteros de 1 a 30', () {
      expect(parseNoticeDays('1'), 1);
      expect(parseNoticeDays(' 30 '), 30);
    });

    test('rechaza 0, 31, decimales y texto (como el back)', () {
      for (final bad in ['0', '31', '2,5', '2.5', 'abc', '', '-1']) {
        expect(parseNoticeDays(bad), isNull, reason: bad);
      }
    });
  });

  group('RecoveryCase', () {
    test('lee el envase, los días y el depósito', () {
      final c = recoveryCase();
      expect(c.serial, 'SPLG-00197');
      expect(c.product, '10kg');
      expect(c.daysOut, 72);
      expect(c.depositAmount, 25000);
      expect(c.pickup, isNull);
    });

    test('lee la oferta de retiro pendiente y la aceptada', () {
      final pending = recoveryCase(pickup: pickupJson());
      expect(pending.pickup!.accepted, isFalse);
      expect(pending.pickup!.orderId, 'o1');
      final accepted = recoveryCase(pickup: pickupJson(status: 'accepted'));
      expect(accepted.pickup!.accepted, isTrue);
    });

    test('un caso sin envase no se usa', () {
      expect(RecoveryCase.fromJson({'caseId': 'c1'}), isNull);
    });

    test('pickupForOrder sólo encuentra el retiro aceptado de ese pedido', () {
      final cases = [
        recoveryCase(id: 'a', pickup: pickupJson(orderId: 'o1')),
        recoveryCase(
            id: 'b', pickup: pickupJson(status: 'accepted', orderId: 'o2')),
      ];
      expect(pickupForOrder(cases, 'o2')!.caseId, 'b');
      expect(pickupForOrder(cases, 'o1'), isNull);
      expect(pickupForOrder(cases, 'o3'), isNull);
    });
  });
}
