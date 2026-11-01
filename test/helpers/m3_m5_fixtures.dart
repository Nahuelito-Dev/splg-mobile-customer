import 'package:splg_customer/domain/cylinder_recovery.dart';
import 'package:splg_customer/domain/repurchase.dart';

/// Invitación abierta tal como la manda `GET /v2/customers/me/repurchase/invitations`.
Map<String, dynamic> invitationJson({
  String id = 'inv-1',
  String status = 'pending',
  DateTime? expiresAt,
  bool available = true,
  bool withSlot = true,
}) =>
    {
      'invitationId': id,
      'distributorId': 'd1',
      'status': status,
      'projectedDepletionAt': '2026-11-02T12:00:00.000Z',
      'estimateSource': 'history',
      'items': [
        {
          'gasCylinderId': 'g1',
          'type': '10kg',
          'quantity': 2,
          'unitPrice': 9000,
          'subtotal': 18000,
          'available': available,
        },
        {
          'gasCylinderId': 'g2',
          'type': '15kg',
          'quantity': 1,
          'unitPrice': 13000,
          'subtotal': 13000,
          'available': true,
        },
      ],
      'estimatedTotal': 31000,
      'address': {'addressId': 'a1', 'label': 'Av. Corrientes 1234, Posadas'},
      'timeSlot': withSlot
          ? {
              'timeSlotId': 't1',
              'name': 'Mañana',
              'startTime': '09:00',
              'endTime': '13:00'
            }
          : null,
      'paymentMethod': 'cash',
      'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(hours: 5)))
          .toUtc()
          .toIso8601String(),
      'createdAt': '2026-10-31T09:00:00.000Z',
      'respondedAt': null,
      'orderId': null,
    };

RepurchaseInvitation invitation({
  String id = 'inv-1',
  DateTime? expiresAt,
  bool available = true,
}) =>
    RepurchaseInvitation.fromJson(
        invitationJson(id: id, expiresAt: expiresAt, available: available))!;

/// Caso de recupero como lo manda `GET /v2/cylinder-recovery/mine`.
Map<String, dynamic> recoveryCaseJson({
  String id = 'c1',
  String serial = 'SPLG-00197',
  Map<String, dynamic>? pickup,
  int step = 1,
}) =>
    {
      'caseId': id,
      'status': 'open',
      'step': step,
      'depositAmount': 25000,
      'deliveredAt': '2026-08-20T12:00:00.000Z',
      'daysOut': 72,
      'stepDueAt': '2026-11-05T12:00:00.000Z',
      'cylinder': {
        'cylinderId': 'cy1',
        'serial': serial,
        'state': 'with_customer',
        'product': '10kg'
      },
      'lastNotice': null,
      'pickup': pickup,
    };

Map<String, dynamic> pickupJson({
  String status = 'pending',
  String orderId = 'o1',
  String noticeId = 'n1',
}) =>
    {
      'noticeId': noticeId,
      'status': status,
      'orderId': orderId,
      'scheduledDate': '2026-11-04',
      'orderStatus': 'pending',
      'expiresAt': '2026-11-04T23:00:00.000Z',
    };

RecoveryCase recoveryCase({Map<String, dynamic>? pickup, String id = 'c1'}) =>
    RecoveryCase.fromJson(recoveryCaseJson(id: id, pickup: pickup))!;

RecoveryCase recoveryCaseStep2() => RecoveryCase.fromJson(
    recoveryCaseJson(id: 'c2', serial: 'SPLG-00188', step: 2))!;
