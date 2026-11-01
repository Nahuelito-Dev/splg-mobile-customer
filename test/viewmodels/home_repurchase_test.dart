import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/fixtures.dart';
import '../helpers/m3_m5_fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRepurchaseService repurchase;
  late FakeCustomerEventsService events;
  late MockNavigationService nav;
  late MockDialogService dialogs;

  setUp(() {
    registerServices();
    locator.unregister<CartService>();
    locator.registerSingleton<CartService>(FakeCart());
    repurchase = locator<RepurchaseService>() as FakeRepurchaseService;
    events = locator<CustomerEventsService>() as FakeCustomerEventsService;
    nav = locator<NavigationService>() as MockNavigationService;
    dialogs = locator<DialogService>() as MockDialogService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.customer).thenReturn(customerWith());
    when(customers.isUserLoggedIn).thenReturn(true);
    final history = locator<HistoryService>() as MockHistoryService;
    when(history.history).thenReturn(<Order>[]);
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenAnswer((_) async => [cylinder()]);
  });
  tearDown(() => locator.reset());

  Future<HomeViewModel> opened({List<RepurchaseInvitation>? open}) async {
    if (open != null) repurchase.invitationsResult = ApiResult.ok(open);
    final m = HomeViewModel();
    await m.initialize();
    return m;
  }

  group('Inicio con recompra (M3) -', () {
    test('con el módulo apagado (sin invitaciones) no muestra nada', () async {
      final m = await opened(open: []);
      expect(m.invitation, isNull);
      expect(m.showRepurchase, isFalse);
      m.dispose();
    });

    test('con una invitación abierta muestra la tarjeta', () async {
      final m = await opened(open: [invitation()]);
      expect(m.showRepurchase, isTrue);
      expect(m.invitation!.itemsLabel, '2 × 10kg · 1 × 15kg');
      m.dispose();
    });

    test('una invitación vencida no se muestra', () async {
      final m = await opened(open: [
        invitation(expiresAt: DateTime.now().subtract(const Duration(hours: 1)))
      ]);
      expect(m.showRepurchase, isFalse);
      m.dispose();
    });

    test('si falla leer las invitaciones el Inicio sigue sin tarjeta',
        () async {
      repurchase.invitationsResult = const ApiResult.fail('Sin conexión.');
      final m = HomeViewModel();
      await m.initialize();
      expect(m.showRepurchase, isFalse);
      expect(m.loadError, isNull);
      m.dispose();
    });

    test('sin sesión no consulta ni abre el socket', () async {
      final customers = locator<CustomerService>() as MockCustomerService;
      when(customers.isUserLoggedIn).thenReturn(false);
      final m = await opened();
      expect(repurchase.calls, isEmpty);
      expect(events.connects, 0);
      m.dispose();
    });

    test('al abrir engancha el socket y al cerrar lo suelta', () async {
      final m = await opened(open: []);
      expect(events.connects, 1);
      m.dispose();
      expect(events.disconnects, 1);
    });

    test('un aviso por socket (repurchase:invitation) trae la invitación',
        () async {
      final m = await opened(open: []);
      expect(m.showRepurchase, isFalse);
      repurchase.invitationsResult = ApiResult.ok([invitation()]);
      events.invitations.add(const RepurchaseInvitationEvent('inv-1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(m.showRepurchase, isTrue);
      m.dispose();
    });

    test('repurchase:invitation-closed cierra la tarjeta', () async {
      final m = await opened(open: [invitation()]);
      events.closed.add(const RepurchaseClosedEvent('inv-1', 'cancelled'));
      await Future<void>.delayed(Duration.zero);
      expect(m.showRepurchase, isFalse);
      m.dispose();
    });

    test('el cierre de otra invitación no toca la que se está viendo',
        () async {
      final m = await opened(open: [invitation()]);
      events.closed.add(const RepurchaseClosedEvent('otra', 'expired'));
      await Future<void>.delayed(Duration.zero);
      expect(m.showRepurchase, isTrue);
      m.dispose();
    });

    test('«Pedir» acepta en el back y lleva al seguimiento del pedido',
        () async {
      repurchase.acceptResult =
          const ApiResult.ok(RepurchaseAccepted(orderId: 'o77'));
      final m = await opened(open: [invitation()]);
      await m.acceptInvitation();
      expect(repurchase.calls, contains('accept:inv-1'));
      expect(m.showRepurchase, isFalse);
      verify(nav.navigateToOrderTrackingView(orderId: 'o77')).called(1);
      m.dispose();
    });

    test('con Mercado Pago abre el pago antes del seguimiento', () async {
      repurchase.acceptResult = const ApiResult.ok(
          RepurchaseAccepted(orderId: 'o77', paymentUrl: 'https://mp/pay'));
      final m = await opened(open: [invitation()]);
      await m.acceptInvitation();
      verifyInOrder([
        nav.navigateToPaymentWebViewView(paymentUrl: 'https://mp/pay'),
        nav.navigateToOrderTrackingView(orderId: 'o77'),
      ]);
      m.dispose();
    });

    test('si el back rechaza (400) lo muestra y la tarjeta queda', () async {
      repurchase.acceptResult = const ApiResult.fail(
          'La dirección está fuera de cobertura',
          status: 400);
      final m = await opened(open: [invitation()]);
      clearInteractions(nav);
      await m.acceptInvitation();
      expect(m.showRepurchase, isTrue);
      verify(dialogs.showDialog(
        title: 'No pudimos crear tu pedido',
        description: 'La dirección está fuera de cobertura',
        buttonTitle: 'Aceptar',
      )).called(1);
      verifyNoMoreInteractions(nav);
      m.dispose();
    });

    test('un 409 (ya no vale) lo muestra y retira la tarjeta', () async {
      repurchase.acceptResult =
          const ApiResult.fail('La invitación venció', status: 409);
      final m = await opened(open: [invitation()]);
      await m.acceptInvitation();
      expect(m.showRepurchase, isFalse);
      verify(dialogs.showDialog(
        title: 'No pudimos crear tu pedido',
        description: 'La invitación venció',
        buttonTitle: 'Aceptar',
      )).called(1);
      m.dispose();
    });

    test('con una garrafa sin stock no acepta y avisa', () async {
      final m = await opened(open: [invitation(available: false)]);
      await m.acceptInvitation();
      expect(repurchase.calls.where((c) => c.startsWith('accept')), isEmpty);
      verify(dialogs.showDialog(
        title: 'Algo ya no está disponible',
        description: anyNamed('description'),
        buttonTitle: 'Aceptar',
      )).called(1);
      m.dispose();
    });

    test('«Ahora no» descarta la invitación', () async {
      final m = await opened(open: [invitation()]);
      await m.dismissInvitation();
      expect(repurchase.calls, contains('dismiss:inv-1'));
      expect(m.showRepurchase, isFalse);
      m.dispose();
    });

    test('si descartar falla, avisa y la tarjeta queda', () async {
      repurchase.dismissResult = const ApiResult.fail('Sin conexión.');
      final m = await opened(open: [invitation()]);
      await m.dismissInvitation();
      expect(m.showRepurchase, isTrue);
      verify(dialogs.showDialog(
        title: 'No pudimos descartar el aviso',
        description: 'Sin conexión.',
        buttonTitle: 'Aceptar',
      )).called(1);
      m.dispose();
    });

    test('un segundo toque mientras acepta no manda otro pedido', () async {
      final m = await opened(open: [invitation()]);
      final first = m.acceptInvitation();
      final second = m.acceptInvitation();
      await Future.wait([first, second]);
      expect(repurchase.calls.where((c) => c.startsWith('accept')), hasLength(1));
      m.dispose();
    });
  });
}
