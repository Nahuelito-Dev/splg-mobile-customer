import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/customer_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late CustomerEventsService service;

  setUp(() => service = CustomerEventsService());

  group('CustomerEventsServiceTest -', () {
    test('repurchase:invitation avisa con el id', () async {
      final next = service.repurchaseInvitations.first;
      service.onInvitation({
        'invitationId': 'inv-1',
        'distributorId': 'd1',
        'expiresAt': '2026-11-01T00:00:00.000Z',
      });
      expect((await next).invitationId, 'inv-1');
    });

    test('repurchase:invitation-closed trae id y motivo', () async {
      final next = service.repurchaseClosed.first;
      service.onInvitationClosed(
          {'invitationId': 'inv-1', 'reason': 'cancelled'});
      final e = await next;
      expect(e.invitationId, 'inv-1');
      expect(e.reason, 'cancelled');
    });

    test('cylinder-recovery:notice trae el caso y el texto', () async {
      final next = service.recoveryNotices.first;
      service.onRecoveryNotice({
        'caseId': 'c1',
        'kind': 'pickup_offer',
        'title': 'Envase sin devolver',
        'body': 'Podés devolverlo en tu entrega',
      });
      final e = await next;
      expect(e.caseId, 'c1');
      expect(e.kind, 'pickup_offer');
      expect(e.title, 'Envase sin devolver');
    });

    test('un payload que no es un mapa no rompe', () async {
      final next = service.repurchaseInvitations.first;
      service.onInvitation('basura');
      expect((await next).invitationId, isNull);
    });

    test('sin sesión no abre ninguna conexión', () {
      registerServices();
      when(locator<CustomerService>().isUserLoggedIn).thenReturn(false);
      service.connect();
      expect(service.isConnected, isFalse);
      locator.reset();
    });
  });
}
