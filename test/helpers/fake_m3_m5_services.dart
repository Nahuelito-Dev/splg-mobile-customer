import 'dart:async';

import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/cylinder_recovery.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';
import 'package:splg_customer/services/repurchase_service.dart';

/// Recompra con respuestas armadas por el test; registra las llamadas.
class FakeRepurchaseService implements RepurchaseService {
  ApiResult<RepurchaseForecast> forecastResult =
      const ApiResult.ok(RepurchaseForecast());
  ApiResult<RepurchaseNotice> noticeResult =
      const ApiResult.ok(RepurchaseNotice());
  ApiResult<RepurchaseNotice> saveResult =
      const ApiResult.ok(RepurchaseNotice());
  ApiResult<List<RepurchaseInvitation>> invitationsResult =
      const ApiResult.ok([]);
  ApiResult<RepurchaseAccepted> acceptResult =
      const ApiResult.ok(RepurchaseAccepted(orderId: 'o1'));
  ApiResult<void> dismissResult = const ApiResult.ok();

  final calls = <String>[];
  Map<String, Object?>? lastSave;

  @override
  Future<ApiResult<RepurchaseForecast>> forecast() async {
    calls.add('forecast');
    return forecastResult;
  }

  @override
  Future<ApiResult<RepurchaseNotice>> notice() async {
    calls.add('notice');
    return noticeResult;
  }

  @override
  Future<ApiResult<RepurchaseNotice>> saveNotice({
    bool? enabled,
    int? days,
    bool useDistributorDays = false,
  }) async {
    calls.add('saveNotice');
    lastSave = {
      'enabled': enabled,
      'days': days,
      'useDistributorDays': useDistributorDays,
    };
    return saveResult;
  }

  @override
  Future<ApiResult<List<RepurchaseInvitation>>> openInvitations() async {
    calls.add('invitations');
    return invitationsResult;
  }

  @override
  Future<ApiResult<RepurchaseAccepted>> accept(String invitationId) async {
    calls.add('accept:$invitationId');
    return acceptResult;
  }

  @override
  Future<ApiResult<void>> dismiss(String invitationId) async {
    calls.add('dismiss:$invitationId');
    return dismissResult;
  }
}

/// Recupero de envases con respuestas armadas por el test.
class FakeCylinderRecoveryService implements CylinderRecoveryService {
  ApiResult<List<RecoveryCase>> mineResult = const ApiResult.ok([]);
  ApiResult<void> answerResult = const ApiResult.ok();

  final calls = <String>[];

  @override
  Future<ApiResult<List<RecoveryCase>>> mine() async {
    calls.add('mine');
    return mineResult;
  }

  @override
  Future<ApiResult<void>> acceptPickup(String caseId) async {
    calls.add('accept:$caseId');
    return answerResult;
  }

  @override
  Future<ApiResult<void>> declinePickup(String caseId) async {
    calls.add('decline:$caseId');
    return answerResult;
  }
}

/// Avisos en vivo que el test dispara a mano.
class FakeCustomerEventsService implements CustomerEventsService {
  final invitations = StreamController<RepurchaseInvitationEvent>.broadcast();
  final closed = StreamController<RepurchaseClosedEvent>.broadcast();
  final recovery = StreamController<RecoveryNoticeEvent>.broadcast();

  int connects = 0;
  int disconnects = 0;

  @override
  Stream<RepurchaseInvitationEvent> get repurchaseInvitations =>
      invitations.stream;
  @override
  Stream<RepurchaseClosedEvent> get repurchaseClosed => closed.stream;
  @override
  Stream<RecoveryNoticeEvent> get recoveryNotices => recovery.stream;

  @override
  bool get isConnected => connects > disconnects;

  @override
  void connect() => connects++;

  @override
  void disconnect() => disconnects++;

  @override
  void onInvitation(dynamic payload) {}
  @override
  void onInvitationClosed(dynamic payload) {}
  @override
  void onRecoveryNotice(dynamic payload) {}
}
