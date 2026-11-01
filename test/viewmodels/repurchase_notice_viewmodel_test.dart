import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_customer/ui/views/repurchase_notice/repurchase_notice_viewmodel.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/test_helpers.dart';

void main() {
  late FakeRepurchaseService service;

  setUpAll(() => initializeDateFormatting('es_AR', null));

  setUp(() {
    registerServices();
    service = locator<RepurchaseService>() as FakeRepurchaseService;
    service.forecastResult = ApiResult.ok(RepurchaseForecast(
      estimatedAt: DateTime(2026, 11, 10),
      daysLeft: 10,
      notice: const RepurchaseNotice(
          enabled: true, days: null, distributorDays: 3, effectiveDays: 3),
    ));
  });
  tearDown(() => locator.reset());

  Future<RepurchaseNoticeViewModel> opened() async {
    final m = RepurchaseNoticeViewModel();
    await m.load();
    return m;
  }

  group('RepurchaseNoticeViewModel Tests -', () {
    test('muestra la fecha estimada y los días del aviso', () async {
      final m = await opened();
      expect(m.loadError, isNull);
      expect(m.estimateText,
          'Próxima recompra estimada: 10/11/2026 (en 10 días)');
      expect(m.daysText, contains('3 días antes'));
      expect(m.daysText, contains('distribuidora'));
    });

    test('sin fecha explica por qué', () async {
      service.forecastResult = const ApiResult.ok(
          RepurchaseForecast(reason: 'no_purchases'));
      final m = await opened();
      expect(m.estimateText, contains('Todavía no hiciste pedidos'));
    });

    test('hoy, mañana y atrasado se leen en lenguaje natural', () async {
      RepurchaseForecast at(int left) => RepurchaseForecast(
          estimatedAt: DateTime(2026, 11, 10), daysLeft: left);
      for (final (left, text) in [
        (0, '(hoy)'),
        (1, '(mañana)'),
        (-2, '(ya te tocaría)')
      ]) {
        service.forecastResult = ApiResult.ok(at(left));
        final m = await opened();
        expect(m.estimateText, endsWith(text));
      }
    });

    test('si no cargó, ofrece reintentar con el texto del back', () async {
      service.forecastResult = const ApiResult.fail('Sin conexión.');
      final m = await opened();
      expect(m.loadError, 'Sin conexión.');
    });

    test('valida los días (1 a 30, entero) antes de llamar al back', () async {
      final m = await opened();
      for (final bad in ['0', '31', '2,5', 'x', '']) {
        m.days.text = bad;
        await m.saveDays();
        expect(m.daysError, isNotNull, reason: bad);
      }
      expect(service.calls.where((c) => c == 'saveNotice'), isEmpty);
    });

    test('guarda los días elegidos y muestra el aviso nuevo', () async {
      service.saveResult = const ApiResult.ok(
          RepurchaseNotice(enabled: true, days: 7, effectiveDays: 7));
      final m = await opened();
      m.days.text = '7';
      await m.saveDays();
      expect(service.lastSave, {
        'enabled': null,
        'days': 7,
        'useDistributorDays': false,
      });
      expect(m.saved, isTrue);
      expect(m.notice.days, 7);
      expect(m.daysText, 'Te avisamos 7 días antes.');
      expect(m.days.text, isEmpty);
    });

    test('apagar el aviso lo manda y refleja el cambio', () async {
      service.saveResult = const ApiResult.ok(RepurchaseNotice(enabled: false));
      final m = await opened();
      await m.setEnabled(false);
      expect(service.lastSave!['enabled'], false);
      expect(m.notice.enabled, isFalse);
      // La fecha estimada sigue.
      expect(m.estimateText, contains('10/11/2026'));
    });

    test('volver al valor de la distribuidora manda days: null', () async {
      service.saveResult = const ApiResult.ok(
          RepurchaseNotice(enabled: true, distributorDays: 3, effectiveDays: 3));
      final m = await opened();
      await m.useDistributorDays();
      expect(service.lastSave!['useDistributorDays'], true);
      expect(m.notice.usesDistributorDays, isTrue);
    });

    test('un rechazo del back se muestra y no cambia lo que había', () async {
      service.saveResult =
          const ApiResult.fail('days must not be greater than 30', status: 400);
      final m = await opened();
      m.days.text = '10';
      await m.saveDays();
      expect(m.saveError, 'days must not be greater than 30');
      expect(m.saved, isFalse);
      expect(m.notice.effectiveDays, 3);
    });
  });
}
