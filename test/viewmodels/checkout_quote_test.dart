import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockHistoryService history;
  late FakeCart cart;
  late List<PaymentMethod> asked;

  Future<void> wait([int ms = 30]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  void stubQuote(QuoteOutcome Function(Order order) answer) {
    when(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')))
        .thenAnswer((i) async {
      final order = i.positionalArguments.first as Order;
      asked.add(order.paymentMethod);
      return answer(order);
    });
  }

  QuoteOutcome byBack(Order order) => backQuote(
        paymentSurcharge: order.paymentMethod == PaymentMethod.cash ? 0 : 180,
        zoneSurcharge: 50,
        zoneName: 'Centro',
      );

  setUp(() {
    registerServices();
    CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 10);
    asked = [];
    history = locator<HistoryService>() as MockHistoryService;
    locator.unregister<CartService>();
    cart = FakeCart()
      ..seedOrder(order(
        items: [OrderItem(cylinder: cylinder(price: 1000), quantity: 2)],
        address: addr('a1', 'Mitre 100'),
      ));
    locator.registerSingleton<CartService>(cart);
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.isUserLoggedIn).thenReturn(true);
    when(customers.customer)
        .thenReturn(customerWith([addr('a1', 'Mitre 100', primary: true)]));
    final slots = locator<TimeSlotService>() as MockTimeSlotService;
    when(slots.availabilityFor(any)).thenAnswer((_) async => const [
          TimeSlotAvailability(
              timeSlotId: 's1',
              name: 'Mañana',
              startTime: '08:00:00',
              endTime: '12:00:00',
              remaining: 5),
        ]);
    stubQuote(byBack);
  });

  tearDown(() {
    CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 400);
    locator.reset();
  });

  test('el total sale de la cotización del back, no de una cuenta local',
      () async {
    final model = CheckoutViewModel()..initialize();
    expect(model.quote, isNull);
    expect(model.quoting, isTrue);

    await wait();

    final quote = model.quote!;
    // Precio del back (900 c/u, con promoción), más zona; la app no recalcula.
    expect(quote.total, 1850);
    expect(quote.zoneSurcharge, 50);
    expect(model.quoting, isFalse);
    expect(model.quoteLineFor(cart.order!.items.first)!.subtotal, 1800);
    model.dispose();
  });

  test('Mercado Pago también trae recargo: lo dice el back, no la app',
      () async {
    final model = CheckoutViewModel()..initialize();
    await wait();
    expect(model.quote!.paymentSurcharge, 0);

    model.setPaymentMethod(PaymentMethod.mercadoPago);
    expect(model.quote, isNull);
    await wait();

    expect(asked.last, PaymentMethod.mercadoPago);
    expect(model.quote!.paymentSurcharge, 180);
    expect(model.quote!.total, 2030);
    model.dispose();
  });

  test('varios cambios seguidos piden una sola cotización (debounce)',
      () async {
    CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 60);
    final model = CheckoutViewModel()..initialize();
    await wait(5);
    model.setPaymentMethod(PaymentMethod.online);
    model.setPaymentMethod(PaymentMethod.mercadoPago);
    model.setPaymentMethod(PaymentMethod.cash);
    await wait(150);

    verify(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')))
        .called(1);
    expect(asked, [PaymentMethod.cash]);
    model.dispose();
  });

  test('una respuesta vieja no pisa a la última', () async {
    final first = Completer<QuoteOutcome>();
    var calls = 0;
    when(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')))
        .thenAnswer((i) {
      if (++calls == 1) return first.future;
      return Future.value(byBack(i.positionalArguments.first as Order));
    });
    final model = CheckoutViewModel()..initialize();
    await wait(); // sale la primera, queda colgada
    model.setPaymentMethod(PaymentMethod.mercadoPago);
    await wait(); // sale la segunda y responde

    first.complete(backQuote(unit: 1, paymentSurcharge: 0));
    await wait();

    expect(model.quote!.paymentSurcharge, 180);
    expect(model.quote!.total, 2030);
    model.dispose();
  });

  test('si el back rechaza, muestra su mensaje y no deja confirmar', () async {
    stubQuote((_) => const QuoteOutcome.failed(
        'La dirección está fuera de la zona de cobertura',
        retryable: false));
    final model = CheckoutViewModel()..initialize();
    await wait();
    model.selectTimeSlot('s1');
    await wait();

    expect(model.quote, isNull);
    expect(model.quoteError, 'La dirección está fuera de la zona de cobertura');
    expect(model.canRetryQuote, isFalse);
    expect(model.canConfirmOrder, isFalse);
    model.dispose();
  });

  test('ante una falla pasajera se puede reintentar y se recupera', () async {
    var fail = true;
    stubQuote((o) => fail
        ? const QuoteOutcome.failed('Sin conexión. Revisá tu internet.')
        : byBack(o));
    final model = CheckoutViewModel()..initialize();
    await wait();
    expect(model.canRetryQuote, isTrue);

    fail = false;
    model.retryQuote();
    await wait();

    expect(model.quoteError, isNull);
    expect(model.quote!.total, 1850);
    model.dispose();
  });

  test('con cotización deja confirmar, con o sin franja; mientras cotiza no',
      () async {
    final model = CheckoutViewModel()..initialize();
    await wait(); // franjas + cotización
    expect(model.canConfirmOrder, isTrue); // sin franja: lo antes posible

    model.selectTimeSlot('s1');
    expect(model.canConfirmOrder, isFalse); // cotizando de nuevo
    await wait();

    expect(model.canConfirmOrder, isTrue);
    model.dispose();
  });

  test('sin dirección no cotiza', () async {
    cart.seedOrder(order(
      items: [OrderItem(cylinder: cylinder(), quantity: 1)],
    ).copyWith(address: null));
    when((locator<CustomerService>() as MockCustomerService).customer)
        .thenReturn(customerWith());

    final model = CheckoutViewModel()..initialize();
    await wait();

    verifyNever(history.quoteOrder(any,
        timeSlotId: anyNamed('timeSlotId'), fromCart: anyNamed('fromCart')));
    expect(model.quote, isNull);
    model.dispose();
  });

  group('confirmar', () {
    late MockCustomerService customers;
    late MockDialogService dialogs;
    late MockNavigationService nav;

    setUp(() {
      customers = locator<CustomerService>() as MockCustomerService;
      dialogs = locator<DialogService>() as MockDialogService;
      nav = locator<NavigationService>() as MockNavigationService;
    });

    Future<CheckoutViewModel> listo() async {
      final model = CheckoutViewModel()..initialize();
      await wait();
      model.selectTimeSlot('s1');
      await wait();
      expect(model.canConfirmOrder, isTrue);
      return model;
    }

    test(
        'si al releer la dirección sólo cambia el texto armado, el pedido se envía',
        () async {
      // El perfil del login trae la dirección sin texto armado ni indicaciones;
      // la lista releída al confirmar sí los trae. No es otra dirección: no
      // tiene que recotizar (antes quedaba en un bucle y nunca enviaba).
      when(customers.refreshAddresses()).thenAnswer((_) async {
        when(customers.customer).thenReturn(customerWith([
          addr('a1', 'Mitre 100', primary: true).copyWith(
            formattedAddress: 'Mitre 100, Posadas, Misiones',
            additionalInstructions: 'Portón verde',
          ),
        ]));
      });
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => const CreateOrderResult(success: false));
      final model = await listo();

      await model.confirmOrder();

      verify(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: true,
              expectedTotal: anyNamed('expectedTotal')))
          .called(1);
      model.dispose();
    });

    test('mientras confirma no se puede cambiar el medio de pago ni la franja',
        () async {
      final gate = Completer<void>();
      when(customers.refreshAddresses()).thenAnswer((_) => gate.future);
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => const CreateOrderResult(success: false));
      final model = await listo();

      final f = model.confirmOrder();
      model.setPaymentMethod(PaymentMethod.mercadoPago); // se ignora
      model.selectTimeSlot('otra'); // se ignora
      gate.complete();
      await f;

      final sent = verify(history.createOrder(captureAny,
              timeSlotId: captureAnyNamed('timeSlotId'),
              fromCart: true,
              expectedTotal: anyNamed('expectedTotal')))
          .captured;
      expect((sent[0] as Order).paymentMethod, PaymentMethod.cash);
      expect(sent[1], 's1');
      model.dispose();
    });

    test('manda como expectedTotal el total de la cotización que se mostró',
        () async {
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => const CreateOrderResult(success: false));
      final model = await listo();
      final mostrado = model.quote!.total;

      await model.confirmOrder();

      final sent = verify(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: captureAnyNamed('expectedTotal')))
          .captured
          .single as double;
      expect(sent, mostrado);
      expect(sent, 1850);
      model.dispose();
    });

    test(
        '409 «Cambió el precio»: no se crea nada, avisa y vuelve a cotizar para confirmar de nuevo',
        () async {
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => const CreateOrderResult(
              success: false,
              priceChanged: true,
              retryable: false,
              message:
                  'Cambió el precio: revisá el total y confirmá de nuevo'));
      final model = await listo();
      final cotizacionesAntes = asked.length;

      await model.confirmOrder();
      await wait(60);

      final dialogs = locator<DialogService>() as MockDialogService;
      verify(dialogs.showDialog(
        title: 'Cambió el precio',
        description: anyNamed('description'),
        buttonTitle: anyNamed('buttonTitle'),
      )).called(1);
      // vuelve a cotizar y no sigue al pago ni al seguimiento
      expect(asked.length, greaterThan(cotizacionesAntes));
      verifyNever(locator<NavigationService>().clearTillFirstAndShow(
        Routes.orderTrackingView,
        arguments: anyNamed('arguments'),
      ));
      model.dispose();
    });

    test('las notas que se escriben mientras espera no cambian lo cotizado',
        () async {
      final gate = Completer<void>();
      when(customers.refreshAddresses()).thenAnswer((_) => gate.future);
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => const CreateOrderResult(success: false));
      final model = await listo();
      model.deliveryDetailsController.text = 'timbre';

      final f = model.confirmOrder();
      model.deliveryDetailsController.text = 'timbre roto';
      gate.complete();
      await f;

      final sent = verify(history.createOrder(captureAny,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .captured
          .single as Order;
      expect(sent.customerNotes, 'timbre');
      model.dispose();
    });

    test('si la dirección cambia durante la espera, no manda: recotiza',
        () async {
      final gate = Completer<void>();
      when(customers.refreshAddresses()).thenAnswer((_) => gate.future);
      final model = await listo();
      final cotizaciones = verify(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart')))
          .callCount;

      final f = model.confirmOrder();
      // La dirección se corrigió en otra pantalla.
      when(customers.customer)
          .thenReturn(customerWith([addr('a1', 'Mitre 200', primary: true)]));
      gate.complete();
      await f;
      await wait();

      verifyNever(history.createOrder(any,
          timeSlotId: anyNamed('timeSlotId'),
          fromCart: anyNamed('fromCart'),
          expectedTotal: anyNamed('expectedTotal')));
      expect(model.isBusy, isFalse);
      expect(
          verify(history.quoteOrder(any,
                  timeSlotId: anyNamed('timeSlotId'),
                  fromCart: anyNamed('fromCart')))
              .callCount,
          greaterThan(0),
          reason: 'recotizó tras $cotizaciones');
      expect(model.quote, isNotNull);
      model.dispose();
    });

    test('sin cotización vigente no manda nada', () async {
      final model = CheckoutViewModel()..initialize();
      // Todavía cotizando.
      await model.confirmOrder();

      verifyNever(history.createOrder(any,
          timeSlotId: anyNamed('timeSlotId'),
          fromCart: anyNamed('fromCart'),
          expectedTotal: anyNamed('expectedTotal')));
      await wait();
      model.dispose();
    });

    test('si el total real del alta difiere del mostrado, avisa con el real',
        () async {
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => CreateOrderResult(
              success: true, order: order(id: 'n', total: 2000)));
      final model = await listo();

      await model.confirmOrder();

      verify(dialogs.showDialog(
        title: 'El total cambió',
        description: argThat(allOf(contains('\$2.000'), contains('\$1.850')),
            named: 'description'),
        buttonTitle: 'Aceptar',
      )).called(1);
      model.dispose();
    });

    test('si el total real coincide no avisa', () async {
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => CreateOrderResult(
              success: true, order: order(id: 'n', total: 1850)));
      final model = await listo();

      await model.confirmOrder();

      verifyNever(dialogs.showDialog(
        title: 'El total cambió',
        description: anyNamed('description'),
        buttonTitle: anyNamed('buttonTitle'),
      ));
      model.dispose();
    });

    test(
        '422 de la clave: avisa que el pedido puede existir y lleva a Mis '
        'pedidos', () async {
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              expectedTotal: anyNamed('expectedTotal')))
          .thenAnswer((_) async => const CreateOrderResult(
                success: false,
                message: kOrderMaybeCreatedText,
                idempotencyConflict: true,
              ));
      final model = await listo();

      await model.confirmOrder();

      verify(dialogs.showDialog(
        title: 'Revisá Mis pedidos',
        description: kOrderMaybeCreatedText,
        buttonTitle: 'Aceptar',
      )).called(1);
      verify(nav.navigateTo<dynamic>(
        Routes.ordersView,
        arguments: anyNamed('arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).called(1);
      model.dispose();
    });
  });
}
