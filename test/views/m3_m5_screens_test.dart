import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_customer/ui/views/cylinder_recovery/cylinder_recovery_view.dart';
import 'package:splg_customer/ui/views/home/home_view.dart';
import 'package:splg_customer/ui/views/home/widgets/home_map.dart';
import 'package:splg_customer/ui/views/profile/profile_view.dart';
import 'package:splg_customer/ui/views/repurchase_notice/repurchase_notice_view.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/splg_lib.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/fixtures.dart';
import '../helpers/m3_m5_fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

void phoneTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await body(t);
  });
}

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  late FakeRepurchaseService repurchase;
  late FakeCylinderRecoveryService recovery;

  setUpAll(() => initializeDateFormatting('es_AR', null));
  setUp(() => HomeMap.placeholder = true);
  tearDown(() => HomeMap.placeholder = false);

  setUp(() {
    registerServices();
    repurchase = locator<RepurchaseService>() as FakeRepurchaseService;
    recovery = locator<CylinderRecoveryService>() as FakeCylinderRecoveryService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.customer).thenReturn(customerWith([
      addr('a1', 'Buenos Aires 4114', primary: true, city: 'Posadas'),
    ]));
    when(customers.isUserLoggedIn).thenReturn(true);
    final history = locator<HistoryService>() as MockHistoryService;
    when(history.history).thenReturn(<Order>[]);
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenAnswer((_) async => [cylinder()]);
  });
  tearDown(() => locator.reset());

  group('Inicio: tarjeta de recompra', () {
    phoneTest('con la invitación muestra lo habitual y «Pedir» la acepta',
        (t) async {
      repurchase.invitationsResult = ApiResult.ok([invitation()]);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.text('Te estás quedando sin gas'), findsOneWidget);
      expect(find.text('2 × 10kg · 1 × 15kg'), findsOneWidget);
      expect(find.textContaining('Av. Corrientes 1234'), findsOneWidget);
      expect(find.textContaining('Mañana · 09:00 a 13:00'), findsOneWidget);
      await t.tap(find.byKey(const Key('home-repurchase-accept')));
      await settle(t);
      expect(repurchase.calls, contains('accept:inv-1'));
      expect(find.byKey(const Key('home-repurchase-card')), findsNothing);
    });

    phoneTest('«Ahora no» descarta y la tarjeta se va', (t) async {
      repurchase.invitationsResult = ApiResult.ok([invitation()]);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      await t.tap(find.byKey(const Key('home-repurchase-dismiss')));
      await settle(t);
      expect(repurchase.calls, contains('dismiss:inv-1'));
      expect(find.byKey(const Key('home-repurchase-card')), findsNothing);
    });

    phoneTest('con una garrafa sin stock «Pedir» queda deshabilitado',
        (t) async {
      repurchase.invitationsResult =
          ApiResult.ok([invitation(available: false)]);
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.byKey(const Key('home-repurchase-unavailable')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('home-repurchase-accept')),
          warnIfMissed: false);
      await settle(t);
      expect(repurchase.calls.where((c) => c.startsWith('accept')), isEmpty);
    });

    phoneTest('sin invitaciones (módulo apagado) el Inicio queda como antes',
        (t) async {
      await t.pumpWidget(app(const HomeView()));
      await settle(t);
      expect(find.byKey(const Key('home-repurchase-card')), findsNothing);
    });
  });

  group('Perfil y aviso de recompra', () {
    phoneTest('el perfil tiene «Aviso de recompra»', (t) async {
      await t.pumpWidget(app(const ProfileView()));
      await settle(t);
      expect(find.byKey(const Key('profile-repurchase')), findsOneWidget);
    });

    phoneTest('muestra la fecha y guarda los días con validación', (t) async {
      repurchase.forecastResult = ApiResult.ok(RepurchaseForecast(
        estimatedAt: DateTime.now().add(const Duration(days: 9)),
        daysLeft: 9,
        notice: const RepurchaseNotice(
            enabled: true, distributorDays: 3, effectiveDays: 3),
      ));
      await t.pumpWidget(app(const RepurchaseNoticeView()));
      await settle(t);
      expect(find.byKey(const Key('repurchase-estimate')), findsOneWidget);
      expect(find.textContaining('(en 9 días)'), findsOneWidget);

      await t.enterText(find.byKey(const Key('repurchase-days')), '45');
      await t.tap(find.byKey(const Key('repurchase-save')));
      await settle(t);
      expect(find.textContaining('de 1 a 30 días'), findsOneWidget);
      expect(repurchase.calls.where((c) => c == 'saveNotice'), isEmpty);

      repurchase.saveResult = const ApiResult.ok(
          RepurchaseNotice(enabled: true, days: 6, effectiveDays: 6));
      await t.enterText(find.byKey(const Key('repurchase-days')), '6');
      await t.tap(find.byKey(const Key('repurchase-save')));
      await settle(t);
      expect(repurchase.lastSave!['days'], 6);
      expect(find.byKey(const Key('repurchase-saved')), findsOneWidget);
      expect(find.byKey(const Key('repurchase-use-default')), findsOneWidget);
    });

    phoneTest('apagar el aviso esconde los días', (t) async {
      repurchase.forecastResult = const ApiResult.ok(RepurchaseForecast(
          notice: RepurchaseNotice(enabled: true, effectiveDays: 3)));
      await t.pumpWidget(app(const RepurchaseNoticeView()));
      await settle(t);
      expect(find.byKey(const Key('repurchase-days')), findsOneWidget);
      repurchase.saveResult =
          const ApiResult.ok(RepurchaseNotice(enabled: false));
      await t.tap(find.byKey(const Key('repurchase-enabled')));
      await settle(t);
      expect(repurchase.lastSave!['enabled'], false);
      expect(find.byKey(const Key('repurchase-days')), findsNothing);
    });
  });

  group('Envases para devolver', () {
    phoneTest('sin casos dice que no hay nada pendiente', (t) async {
      await t.pumpWidget(app(const CylinderRecoveryView()));
      await settle(t);
      expect(find.text('No tenés envases pendientes de devolución.'),
          findsOneWidget);
    });

    phoneTest('una oferta de retiro se acepta desde la lista', (t) async {
      recovery.mineResult = ApiResult.ok([recoveryCase(pickup: pickupJson())]);
      await t.pumpWidget(app(const CylinderRecoveryView()));
      await settle(t);
      expect(find.text('SPLG-00197'), findsOneWidget);
      recovery.mineResult = ApiResult.ok(
          [recoveryCase(pickup: pickupJson(status: 'accepted'))]);
      await t.tap(find.byKey(const Key('recovery-accept-c1')));
      await settle(t);
      expect(recovery.calls, contains('accept:c1'));
      expect(find.byKey(const Key('recovery-accepted-c1')), findsOneWidget);
      expect(find.byKey(const Key('recovery-accept-c1')), findsNothing);
    });

    phoneTest('rechazar la oferta la manda al back', (t) async {
      recovery.mineResult = ApiResult.ok([recoveryCase(pickup: pickupJson())]);
      await t.pumpWidget(app(const CylinderRecoveryView()));
      await settle(t);
      await t.tap(find.byKey(const Key('recovery-decline-c1')));
      await settle(t);
      expect(recovery.calls, contains('decline:c1'));
    });

    phoneTest('un 409 se muestra bajo el envase', (t) async {
      recovery.mineResult = ApiResult.ok([recoveryCase(pickup: pickupJson())]);
      await t.pumpWidget(app(const CylinderRecoveryView()));
      await settle(t);
      recovery.answerResult =
          const ApiResult.fail('La oferta de retiro venció', status: 409);
      recovery.mineResult = ApiResult.ok([recoveryCase()]);
      await t.tap(find.byKey(const Key('recovery-accept-c1')));
      await settle(t);
      expect(find.byKey(const Key('recovery-error-c1')), findsOneWidget);
      expect(find.text('La oferta de retiro venció'), findsOneWidget);
    });
  });
}
