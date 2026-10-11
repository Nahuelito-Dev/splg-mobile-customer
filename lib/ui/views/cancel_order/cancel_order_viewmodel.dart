import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/history_service.dart';

/// Motivos para cancelar. El último abre un texto libre.
const List<String> kCancelReasons = [
  'Me equivoqué de pedido',
  'Pedí por error',
  'Ya no necesito la garrafa',
  'Tardó demasiado',
  'Otro',
];

class CancelOrderViewModel extends BaseViewModel {
  CancelOrderViewModel({required this.orderId}) {
    // El botón depende del texto de "Otro": se reevalúa al escribir.
    other.addListener(notifyListeners);
  }

  final String orderId;

  final _history = locator<HistoryService>();
  final _nav = locator<NavigationService>();

  final TextEditingController other = TextEditingController();

  String? reason;

  /// Error de la última cancelación (rechazo del back, red, etc.).
  String? errorMessage;

  /// true cuando el pedido quedó cancelado.
  bool done = false;

  bool get isOther => reason == kCancelReasons.last;

  bool get canSubmit =>
      !isBusy && reason != null && (!isOther || other.text.trim().isNotEmpty);

  /// Motivo que se manda al back (la etiqueta, o el texto en "Otro").
  String? get reasonText => isOther ? other.text.trim() : reason;

  @override
  void dispose() {
    other.dispose();
    super.dispose();
  }

  void select(String value) {
    reason = value;
    errorMessage = null;
    notifyListeners();
  }

  /// Cancela con el motivo. Si falla por red o 5xx se puede volver a tocar:
  /// el reintento lleva la misma `Idempotency-Key` (la guarda el caso de uso).
  Future<void> submit() async {
    if (!canSubmit) return;
    errorMessage = null;
    setBusy(true);
    final result = await _history.cancelOrder(orderId, reason: reasonText);
    setBusy(false);
    if (result.success) {
      done = true;
    } else {
      errorMessage = result.failureDescription;
    }
    notifyListeners();
  }

  void close() => _nav.back(result: done);
}
