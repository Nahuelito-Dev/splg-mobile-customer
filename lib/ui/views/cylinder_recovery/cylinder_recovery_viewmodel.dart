import 'dart:async';

import 'package:intl/intl.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/cylinder_recovery.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Envases para devolver (M5): los que el cliente todavía tiene y la oferta de
/// devolverlos en su próxima entrega.
class CylinderRecoveryViewModel extends LoadViewModel {
  final _service = locator<CylinderRecoveryService>();
  final _events = locator<CustomerEventsService>();
  final _nav = locator<NavigationService>();

  List<RecoveryCase> cases = [];

  /// Caso con una respuesta en vuelo (aceptar o rechazar).
  String? answeringCaseId;

  /// Error de la última respuesta, bajo el caso que la dio.
  String? answerError;
  String? answerErrorCaseId;

  StreamSubscription<RecoveryNoticeEvent>? _noticeSubscription;

  Future<void> initialize() async {
    await load();
    // Un aviso nuevo (oferta de retiro, escalón) vuelve a leer la lista sin
    // el loader.
    _noticeSubscription = _events.recoveryNotices.listen((_) => refresh());
  }

  @override
  void dispose() {
    _noticeSubscription?.cancel();
    super.dispose();
  }

  @override
  Future<void> fetch() async {
    final r = await _service.mine();
    if (!r.ok) throw LoadFailure(r.message!);
    cases = r.data!;
  }

  /// Vuelve a leer en silencio; si falla se queda con lo que había.
  Future<void> refresh() async {
    final r = await _service.mine();
    if (r.ok) {
      cases = r.data!;
      notifyListeners();
    }
  }

  /// "Hace 12 días en tu casa".
  String daysOutText(RecoveryCase c) => c.daysOut == 1
      ? 'Lo tenés hace 1 día'
      : 'Lo tenés hace ${c.daysOut} días';

  String stepText(RecoveryCase c) => switch (c.step) {
        1 => 'Te recordamos que lo devuelvas.',
        2 => 'Si no lo devolvés, se te puede cobrar el depósito '
            '(${money.format(c.depositAmount)}).',
        _ => 'Ya pasó el plazo: la distribuidora va a definir cómo seguir. '
            'Depósito en juego: ${money.format(c.depositAmount)}.',
      };

  /// "el 04/11" desde `2026-11-04`; null si no hay fecha.
  String? pickupDay(RecoveryPickup p) {
    final raw = p.scheduledDate;
    final d = raw == null ? null : DateTime.tryParse(raw);
    return d == null ? null : DateFormat('dd/MM', 'es_AR').format(d);
  }

  bool isAnswering(RecoveryCase c) => answeringCaseId == c.caseId;

  Future<void> acceptPickup(RecoveryCase c) =>
      _answer(c, () => _service.acceptPickup(c.caseId));

  Future<void> declinePickup(RecoveryCase c) =>
      _answer(c, () => _service.declinePickup(c.caseId));

  Future<void> _answer(
      RecoveryCase c, Future<dynamic> Function() call) async {
    if (answeringCaseId != null) return;
    answeringCaseId = c.caseId;
    answerError = null;
    answerErrorCaseId = null;
    notifyListeners();
    final r = await call();
    if (!r.ok) {
      answerError = r.message as String?;
      answerErrorCaseId = c.caseId;
    }
    // Aunque falle (la oferta pudo vencer) se lee de nuevo: la lista manda.
    await refresh();
    answeringCaseId = null;
    notifyListeners();
  }

  /// Abre el seguimiento del pedido que lleva el retiro.
  Future<void> openOrder(RecoveryPickup p) =>
      _nav.navigateToOrderTrackingView(orderId: p.orderId);
}
