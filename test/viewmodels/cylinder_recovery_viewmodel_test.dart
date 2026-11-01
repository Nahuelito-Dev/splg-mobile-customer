import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';
import 'package:splg_customer/ui/views/cylinder_recovery/cylinder_recovery_viewmodel.dart';
import 'package:splg_customer/ui/widgets/app_drawer/app_drawer_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/m3_m5_fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late FakeCylinderRecoveryService service;
  late FakeCustomerEventsService events;

  setUpAll(() => initializeDateFormatting('es_AR', null));

  setUp(() {
    registerServices();
    service = locator<CylinderRecoveryService>() as FakeCylinderRecoveryService;
    events = locator<CustomerEventsService>() as FakeCustomerEventsService;
  });
  tearDown(() => locator.reset());

  group('CylinderRecoveryViewModel Tests -', () {
    test('lista los envases con los días y el escalón', () async {
      service.mineResult = ApiResult.ok([
        recoveryCase(),
        recoveryCaseStep2(),
      ]);
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      expect(m.cases, hasLength(2));
      expect(m.daysOutText(m.cases.first), 'Lo tenés hace 72 días');
      expect(m.stepText(m.cases.first), contains('Te recordamos'));
      expect(m.stepText(m.cases.last), contains('\$25.000'));
      m.dispose();
    });

    test('sin casos (módulo apagado) queda la lista vacía, sin error',
        () async {
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      expect(m.loadError, isNull);
      expect(m.cases, isEmpty);
      m.dispose();
    });

    test('si no cargó, ofrece reintentar con el texto del back', () async {
      service.mineResult = const ApiResult.fail('Sin conexión.');
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      expect(m.loadError, 'Sin conexión.');
      m.dispose();
    });

    test('aceptar el retiro lo manda y vuelve a leer la lista', () async {
      final offer = recoveryCase(pickup: pickupJson());
      service.mineResult = ApiResult.ok([offer]);
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      service.mineResult = ApiResult.ok(
          [recoveryCase(pickup: pickupJson(status: 'accepted'))]);
      await m.acceptPickup(offer);
      expect(service.calls, containsAllInOrder(['mine', 'accept:c1', 'mine']));
      expect(m.cases.single.pickup!.accepted, isTrue);
      expect(m.answerError, isNull);
      expect(m.answeringCaseId, isNull);
      m.dispose();
    });

    test('rechazar el retiro lo manda', () async {
      final offer = recoveryCase(pickup: pickupJson());
      service.mineResult = ApiResult.ok([offer]);
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      await m.declinePickup(offer);
      expect(service.calls, contains('decline:c1'));
      m.dispose();
    });

    test('un 409 (la oferta venció) se muestra bajo el caso y se relee',
        () async {
      final offer = recoveryCase(pickup: pickupJson());
      service.mineResult = ApiResult.ok([offer]);
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      service.answerResult =
          const ApiResult.fail('La oferta de retiro venció', status: 409);
      service.mineResult = ApiResult.ok([recoveryCase()]);
      await m.acceptPickup(offer);
      expect(m.answerError, 'La oferta de retiro venció');
      expect(m.answerErrorCaseId, 'c1');
      expect(m.cases.single.pickup, isNull);
      m.dispose();
    });

    test('un aviso por socket vuelve a leer sin loader', () async {
      final m = CylinderRecoveryViewModel();
      await m.initialize();
      expect(m.cases, isEmpty);
      service.mineResult =
          ApiResult.ok([recoveryCase(pickup: pickupJson())]);
      events.recovery.add(const RecoveryNoticeEvent(caseId: 'c1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(m.cases, hasLength(1));
      m.dispose();
    });

    test('«Ver el pedido» abre el seguimiento del pedido del retiro', () async {
      final offer = recoveryCase(pickup: pickupJson(status: 'accepted'));
      final m = CylinderRecoveryViewModel();
      await m.openOrder(offer.pickup!);
      verify((locator<NavigationService>() as MockNavigationService)
              .navigateToOrderTrackingView(orderId: 'o1'))
          .called(1);
      m.dispose();
    });
  });

  group('Menú: «Envases para devolver» -', () {
    test('sin casos la entrada no aparece', () async {
      final m = AppDrawerViewModel();
      await m.loadRecovery();
      expect(m.hasRecoveryCases, isFalse);
    });

    test('con casos aparece', () async {
      service.mineResult = ApiResult.ok([recoveryCase()]);
      final m = AppDrawerViewModel();
      await m.loadRecovery();
      expect(m.hasRecoveryCases, isTrue);
    });

    test('si falla la lectura queda oculta', () async {
      service.mineResult = const ApiResult.fail('Sin conexión.');
      final m = AppDrawerViewModel();
      await m.loadRecovery();
      expect(m.hasRecoveryCases, isFalse);
    });
  });
}
