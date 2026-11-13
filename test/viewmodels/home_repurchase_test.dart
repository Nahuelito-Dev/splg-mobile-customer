import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'package:splg_customer/ui/bottom_sheets/address_list/address_list_sheet_model.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/fake_mercado_pago_checkout_service.dart';
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
  late FakeMercadoPagoCheckoutService mercadoPago;

  setUp(() {
    registerServices();
    locator.unregister<CartService>();
    locator.registerSingleton<CartService>(FakeCart());
    repurchase = locator<RepurchaseService>() as FakeRepurchaseService;
    events = locator<CustomerEventsService>() as FakeCustomerEventsService;
    nav = locator<NavigationService>() as MockNavigationService;
    dialogs = locator<DialogService>() as MockDialogService;
    mercadoPago =
        locator<MercadoPagoCheckoutService>() as FakeMercadoPagoCheckoutService;
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
      expect(mercadoPago.opened, ['https://mp/pay']);
      verify(nav.navigateToOrderTrackingView(orderId: 'o77')).called(1);
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

  group('Dirección de la recompra -', () {
    late MockCustomerService customers;
    late MockBottomSheetService sheets;
    final casa =
        addr('a1', 'Buenos Aires 4114', primary: true, city: 'Posadas');
    final trabajo = addr('a2', 'Mitre 123', city: 'Posadas');

    setUp(() {
      customers = locator<CustomerService>() as MockCustomerService;
      sheets = locator<BottomSheetService>() as MockBottomSheetService;
      when(customers.customer).thenReturn(customerWith([casa, trabajo]));
      repurchase.quoteResult = ApiResult.ok(quoteOf(29500));
    });

    // La cotización con otra dirección llega en otra vuelta del event loop.
    Future<void> quoted() => Future<void>.delayed(Duration.zero);

    void sheetAnswers(SheetResponse<dynamic>? response) =>
        when(sheets.showCustomSheet(
          variant: anyNamed('variant'),
          title: anyNamed('title'),
          data: anyNamed('data'),
        )).thenAnswer((_) async => response);

    test('por omisión usa la dirección elegida en el inicio y es la que manda',
        () async {
      // La invitación es de a1 (la de su última compra); en el inicio eligió a2.
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.chooseAddress();
      expect(m.repurchaseAddressLabel, 'Mitre 123, Posadas');
      await quoted();
      await m.acceptInvitation();
      expect(repurchase.lastAcceptAddressId, 'a2');
      m.dispose();
    });

    test('si la elegida es la de la invitación no manda addressId', () async {
      final m = await opened(open: [invitation()]);
      expect(m.repurchaseAddress?.addressId, 'a1');
      expect(m.repurchaseAddressLabel, 'Buenos Aires 4114, Posadas');
      await m.acceptInvitation();
      expect(repurchase.calls, contains('accept:inv-1'));
      expect(repurchase.lastAcceptAddressId, isNull);
      m.dispose();
    });

    test(
        'sin direcciones guardadas muestra la de la invitación y no manda otra',
        () async {
      when(customers.customer).thenReturn(customerWith());
      final m = await opened(open: [invitation()]);
      expect(m.repurchaseAddressLabel, 'Av. Corrientes 1234, Posadas');
      await m.acceptInvitation();
      expect(repurchase.lastAcceptAddressId, isNull);
      m.dispose();
    });

    test('«Cambiar» usa el selector de direcciones y cambia sólo la recompra',
        () async {
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      verify(sheets.showCustomSheet(
        variant: BottomSheetType.addressList,
        title: anyNamed('title'),
        data: {'selectedId': 'a1'},
      )).called(1);
      expect(m.repurchaseAddressLabel, 'Mitre 123, Posadas');
      // La del inicio (y la del carrito) no cambia.
      expect(m.deliveryAddress?.addressId, 'a1');
      await quoted();
      await m.acceptInvitation();
      expect(repurchase.lastAcceptAddressId, 'a2');
      m.dispose();
    });

    test('cerrar el selector sin elegir no cambia nada', () async {
      final m = await opened(open: [invitation()]);
      sheetAnswers(null);
      await m.changeRepurchaseAddress();
      expect(m.repurchaseAddress?.addressId, 'a1');
      m.dispose();
    });

    test('«Agregar» desde el selector usa la dirección recién creada',
        () async {
      final nueva = addr('a3', 'Colón 50', city: 'Posadas');
      when(customers.customer).thenReturn(customerWith([casa, trabajo, nueva]));
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(data: AddressListSheetModel.addNew));
      when(nav.navigateTo<dynamic>(
        Routes.addressFormView,
        arguments: anyNamed('arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).thenAnswer((_) async => nueva);
      await m.changeRepurchaseAddress();
      expect(m.repurchaseAddressLabel, 'Colón 50, Posadas');
      await quoted();
      await m.acceptInvitation();
      expect(repurchase.lastAcceptAddressId, 'a3');
      m.dispose();
    });

    test(
        'un 404 (la dirección ya no es suya) muestra el motivo, relee las '
        'direcciones y la tarjeta queda', () async {
      when(customers.refreshAddresses()).thenAnswer((_) async {});
      repurchase.acceptResult = const ApiResult.fail(
          'No encontramos esa dirección entre las tuyas',
          status: 404);
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      await quoted();
      clearInteractions(customers);
      await m.acceptInvitation();
      expect(m.showRepurchase, isTrue);
      verify(dialogs.showDialog(
        title: 'No pudimos crear tu pedido',
        description: 'No encontramos esa dirección entre las tuyas',
        buttonTitle: 'Aceptar',
      )).called(1);
      await Future<void>.delayed(Duration.zero);
      verify(customers.refreshAddresses()).called(1);
      m.dispose();
    });

    test('con la dirección de la invitación usa su total y no cotiza',
        () async {
      final m = await opened(open: [invitation()]);
      expect(m.repurchaseTotalText, 'Total aproximado \$31.000');
      expect(m.canAcceptRepurchase, isTrue);
      expect(repurchase.quoted, isEmpty);
      m.dispose();
    });

    test('con otra dirección cotiza: «Calculando…» y sin «Pedir» hasta que '
        'llega el total', () async {
      final m = await opened(open: [invitation()]);
      repurchase.quoteGate = Completer<void>();
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      expect(m.repurchaseTotalText, 'Calculando…');
      expect(m.canAcceptRepurchase, isFalse);
      await m.acceptInvitation();
      expect(repurchase.calls.where((c) => c.startsWith('accept')), isEmpty);

      repurchase.quoteGate!.complete();
      await quoted();
      expect(repurchase.quoted, ['a2']);
      expect(m.repurchaseTotalText, 'Total aproximado \$29.500');
      expect(m.canAcceptRepurchase, isTrue);
      m.dispose();
    });

    test('elegir otra dirección en el inicio también recotiza', () async {
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.chooseAddress();
      await quoted();
      expect(repurchase.quoted, ['a2']);
      expect(m.repurchaseTotalText, 'Total aproximado \$29.500');
      m.dispose();
    });

    test('si la cotización falla (fuera de cobertura) muestra el motivo y no '
        'deja pedir hasta elegir otra', () async {
      repurchase.quoteResult = const ApiResult.fail(
          'La dirección está fuera de la zona de cobertura de la distribuidora',
          status: 400);
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      await quoted();
      expect(m.repurchaseQuoteError,
          'La dirección está fuera de la zona de cobertura de la distribuidora');
      expect(m.repurchaseTotalText, isNull);
      expect(m.canAcceptRepurchase, isFalse);
      expect(m.showRepurchase, isTrue);
      await m.acceptInvitation();
      expect(repurchase.calls.where((c) => c.startsWith('accept')), isEmpty);

      // Vuelve a la de la invitación: su total, sin error y con «Pedir».
      sheetAnswers(SheetResponse(confirmed: true, data: casa));
      await m.changeRepurchaseAddress();
      expect(m.repurchaseQuoteError, isNull);
      expect(m.repurchaseTotalText, 'Total aproximado \$31.000');
      expect(m.canAcceptRepurchase, isTrue);
      m.dispose();
    });

    test('si la cotización falla por la red se puede reintentar la misma '
        'dirección', () async {
      repurchase.quoteResult = const ApiResult.fail('Sin conexión.');
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      await quoted();
      expect(m.repurchaseQuoteError, 'Sin conexión.');
      expect(m.repurchaseQuoteRetryable, isTrue);
      expect(m.canAcceptRepurchase, isFalse);

      repurchase.quoteResult = ApiResult.ok(quoteOf(29500));
      m.retryRepurchaseQuote();
      expect(m.repurchaseTotalText, 'Calculando…');
      await quoted();
      expect(repurchase.quoted, ['a2', 'a2']);
      expect(m.repurchaseQuoteError, isNull);
      expect(m.repurchaseTotalText, 'Total aproximado \$29.500');
      expect(m.canAcceptRepurchase, isTrue);
      m.dispose();
    });

    test('un 5xx también se reintenta; un 400 o un 404 no', () async {
      Future<bool> retryableFor(int status) async {
        repurchase.quoteResult = ApiResult.fail('motivo', status: status);
        final m = await opened(open: [invitation()]);
        sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
        await m.changeRepurchaseAddress();
        await quoted();
        final retryable = m.repurchaseQuoteRetryable;
        final before = repurchase.quoted.length;
        m.retryRepurchaseQuote();
        await quoted();
        // Sin reintento posible, «Reintentar» no vuelve a cotizar.
        if (!retryable) expect(repurchase.quoted.length, before);
        m.dispose();
        return retryable;
      }

      expect(await retryableFor(503), isTrue);
      expect(await retryableFor(400), isFalse);
      expect(await retryableFor(404), isFalse);
    });

    test('una cotización vieja no pisa la de la dirección actual', () async {
      final m = await opened(open: [invitation()]);
      repurchase.quoteGate = Completer<void>();
      repurchase.quoteResult = const ApiResult.fail('fuera de cobertura');
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      sheetAnswers(SheetResponse(confirmed: true, data: casa));
      await m.changeRepurchaseAddress();
      repurchase.quoteGate!.complete();
      await quoted();
      expect(m.repurchaseQuoteError, isNull);
      expect(m.canAcceptRepurchase, isTrue);
      m.dispose();
    });

    test('A → B → A con respuestas desordenadas: la cotización vieja de A no '
        'pisa la nueva', () async {
      final colon = addr('a3', 'Colón 50', city: 'Posadas');
      when(customers.customer).thenReturn(customerWith([casa, trabajo, colon]));
      final pending = <Completer<ApiResult<OrderQuote>>>[];
      repurchase.quoteResponder = (_) {
        final c = Completer<ApiResult<OrderQuote>>();
        pending.add(c);
        return c.future;
      };
      final m = await opened(open: [invitation()]);
      for (final a in [trabajo, colon, trabajo]) {
        sheetAnswers(SheetResponse(confirmed: true, data: a));
        await m.changeRepurchaseAddress();
      }
      expect(repurchase.quoted, ['a2', 'a3', 'a2']);

      // Llega primero la nueva de A y después la vieja (falló).
      pending[2].complete(ApiResult.ok(quoteOf(29500)));
      await quoted();
      pending[0].complete(const ApiResult.fail('Sin conexión.'));
      pending[1].complete(ApiResult.ok(quoteOf(99999)));
      await quoted();
      expect(m.repurchaseQuoteError, isNull);
      expect(m.repurchaseTotalText, 'Total aproximado \$29.500');
      expect(m.canAcceptRepurchase, isTrue);
      m.dispose();
    });

    test('«Reintentar» descarta la respuesta del intento anterior', () async {
      final pending = <Completer<ApiResult<OrderQuote>>>[];
      repurchase.quoteResponder = (_) {
        final c = Completer<ApiResult<OrderQuote>>();
        pending.add(c);
        return c.future;
      };
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      pending[0].complete(const ApiResult.fail('Sin conexión.'));
      await quoted();
      m.retryRepurchaseQuote();
      pending[1].complete(ApiResult.ok(quoteOf(29500)));
      await quoted();
      expect(m.repurchaseTotalText, 'Total aproximado \$29.500');
      expect(m.canAcceptRepurchase, isTrue);
      m.dispose();
    });

    test('otra invitación vuelve a la dirección del inicio', () async {
      final m = await opened(open: [invitation()]);
      sheetAnswers(SheetResponse(confirmed: true, data: trabajo));
      await m.changeRepurchaseAddress();
      expect(m.repurchaseAddress?.addressId, 'a2');
      repurchase.invitationsResult = ApiResult.ok([invitation(id: 'inv-2')]);
      await m.refreshInvitation();
      expect(m.repurchaseAddress?.addressId, 'a1');
      m.dispose();
    });
  });
}

OrderQuote quoteOf(double total) => OrderQuote(
      lines: const [],
      subtotal: total,
      zoneSurcharge: 0,
      paymentSurcharge: 0,
      deposit: 0,
      total: total,
      balance: total,
    );
