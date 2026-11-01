import 'package:flutter/widgets.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Aviso de recompra (CU-145) y fecha estimada de la próxima compra (CU-146).
class RepurchaseNoticeViewModel extends LoadViewModel {
  final _service = locator<RepurchaseService>();

  final days = TextEditingController();

  RepurchaseForecast forecast = const RepurchaseForecast();

  String? daysError;

  /// Error del último guardado (lo que contestó el back).
  String? saveError;

  /// Se guardó recién: avisa con un texto breve.
  bool saved = false;

  RepurchaseNotice get notice => forecast.notice;

  @override
  void dispose() {
    days.dispose();
    super.dispose();
  }

  @override
  Future<void> fetch() async {
    final r = await _service.forecast();
    if (!r.ok) throw LoadFailure(r.message!);
    forecast = r.data!;
  }

  /// "Próxima recompra estimada: 12/11/2026 (en 5 días)" o el motivo por el que
  /// no hay fecha.
  String get estimateText {
    final at = forecast.estimatedAt;
    if (at == null) return forecast.reasonText;
    final left = forecast.daysLeft;
    final when = switch (left) {
      null => '',
      0 => ' (hoy)',
      1 => ' (mañana)',
      < 0 => ' (ya te tocaría)',
      _ => ' (en $left días)',
    };
    return 'Próxima recompra estimada: ${dateLabel(at)}$when';
  }

  /// Los días con los que rige el aviso, para mostrarlos.
  String get daysText {
    final effective = notice.effectiveDays;
    if (effective == null) return 'Sin días definidos por la distribuidora.';
    final plural = effective == 1 ? 'día' : 'días';
    return notice.usesDistributorDays
        ? 'Te avisamos $effective $plural antes (el valor de tu distribuidora).'
        : 'Te avisamos $effective $plural antes.';
  }

  Future<void> setEnabled(bool value) async {
    if (isBusy) return;
    await _save(() => _service.saveNotice(enabled: value));
  }

  Future<void> saveDays() async {
    if (isBusy) return;
    final value = parseNoticeDays(days.text);
    if (value == null) {
      daysError = 'Ingresá un número entero de '
          '$repurchaseNoticeMinDays a $repurchaseNoticeMaxDays días.';
      saved = false;
      saveError = null;
      notifyListeners();
      return;
    }
    daysError = null;
    await _save(() => _service.saveNotice(days: value));
  }

  Future<void> useDistributorDays() async {
    if (isBusy) return;
    daysError = null;
    await _save(() => _service.saveNotice(useDistributorDays: true));
  }

  Future<void> _save(Future<ApiResult<RepurchaseNotice>> Function() call) async {
    saved = false;
    saveError = null;
    setBusy(true);
    final r = await call();
    if (r.ok) {
      forecast = RepurchaseForecast(
        estimatedAt: forecast.estimatedAt,
        daysLeft: forecast.daysLeft,
        reason: forecast.reason,
        notice: r.data!,
        openInvitation: forecast.openInvitation,
      );
      days.clear();
      saved = true;
    } else {
      saveError = r.message;
    }
    setBusy(false);
  }
}
