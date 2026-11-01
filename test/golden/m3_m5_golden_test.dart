import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
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
import 'package:splg_customer/ui/views/repurchase_notice/repurchase_notice_view.dart';
import 'package:splg_customer/ui/widgets/app_drawer/app_drawer.dart';
import 'package:splg_lib/domain/order.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/fixtures.dart';
import '../helpers/m3_m5_fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';
import 'screens_golden_test.dart' show check, pumpScreen;

/// Goldens de las pantallas de recompra (M3) y recupero de envases (M5).
void main() {
  setUpAll(() => initializeDateFormatting('es_AR', null));
  setUp(() => HomeMap.placeholder = true);
  tearDown(() => HomeMap.placeholder = false);

  setUp(() {
    registerServices();
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

  testGoldens('Inicio con la invitación de recompra', (t) async {
    await loadAppFonts();
    (locator<RepurchaseService>() as FakeRepurchaseService).invitationsResult =
        ApiResult.ok([invitation()]);
    await pumpScreen(t, const HomeView());
    expect(find.byKey(const Key('home-repurchase-card')), findsOneWidget);
    await check(t, 'home_repurchase');
  });

  testGoldens('Aviso de recompra', (t) async {
    await loadAppFonts();
    (locator<RepurchaseService>() as FakeRepurchaseService).forecastResult =
        ApiResult.ok(RepurchaseForecast(
      estimatedAt: DateTime.now().add(const Duration(days: 9)),
      daysLeft: 9,
      notice: const RepurchaseNotice(
          enabled: true, days: 5, distributorDays: 3, effectiveDays: 5),
    ));
    await pumpScreen(t, const RepurchaseNoticeView());
    await check(t, 'repurchase_notice');
  });

  testGoldens('Envases para devolver', (t) async {
    await loadAppFonts();
    (locator<CylinderRecoveryService>() as FakeCylinderRecoveryService)
        .mineResult = ApiResult.ok([
      recoveryCase(pickup: pickupJson()),
      recoveryCase(
          id: 'c2',
          pickup: pickupJson(status: 'accepted', orderId: 'o2')),
      recoveryCaseStep2(),
    ]);
    await pumpScreen(t, const CylinderRecoveryView());
    await check(t, 'cylinder_recovery');
  });

  testGoldens('Menú con envases para devolver', (t) async {
    await loadAppFonts();
    (locator<CylinderRecoveryService>() as FakeCylinderRecoveryService)
        .mineResult = ApiResult.ok([recoveryCase()]);
    await pumpScreen(t, const Scaffold(drawer: AppDrawer()), drawer: true);
    await check(t, 'menu_recovery');
  });
}
