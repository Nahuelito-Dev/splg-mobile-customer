import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

const _standard = DeliveryOption(
    mode: DeliveryMode.standard, available: true, estimatedMinutes: 180);
const _expressOk = DeliveryOption(
    mode: DeliveryMode.express,
    available: true,
    surchargeAmount: 2350,
    estimatedMinutes: 45);
const _expressOff = DeliveryOption(
    mode: DeliveryMode.express,
    available: false,
    reason: 'no_motorcycle_driver',
    estimatedMinutes: 45);

void main() {
  late MockHistoryService history;
  late MockDialogService dialogs;
  late MockNavigationService nav;
  late FakeCart cart;
  late List<DeliveryMode> quotedModes;

  Future<void> wait([int ms = 30]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  void stubOptions(DeliveryOption expressOption) {
    when(history.deliveryOptions(any)).thenAnswer(
        (_) async => ApiResult.ok(DeliveryOptions([_standard, expressOption])));
  }

  QuoteOutcome quoteFor(DeliveryMode mode) {
    final isExpress = mode == DeliveryMode.express;
    return QuoteOutcome.ok(OrderQuote(
      lines: const [
        QuoteLine(
            gasCylinderId: 'g1', quantity: 2, unitPrice: 1000, subtotal: 2000)
      ],
      subtotal: 2000,
      zoneSurcharge: 0,
      paymentSurcharge: 0,
      deposit: 0,
      total: isExpress ? 4350 : 2000,
      balance: isExpress ? 4350 : 2000,
      deliveryMode: mode,
      expressSurcharge: isExpress ? 2350 : 0,
    ));
  }

  void stubQuote() {
    when(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'),
            fromCart: anyNamed('fromCart'),
            deliveryMode: anyNamed('deliveryMode')))
        .thenAnswer((i) async {
      final mode = i.namedArguments[#deliveryMode] as DeliveryMode;
      quotedModes.add(mode);
      return quoteFor(mode);
    });
  }

  setUp(() {
    registerServices();
    CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 10);
    quotedModes = [];
    history = locator<HistoryService>() as MockHistoryService;
    dialogs = locator<DialogService>() as MockDialogService;
    nav = locator<NavigationService>() as MockNavigationService;
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
    stubOptions(_expressOk);
    stubQuote();
  });

  tearDown(() {
    CheckoutViewModel.quoteDebounce = const Duration(milliseconds: 400);
    locator.reset();
  });

  Future<CheckoutViewModel> ready() async {
    final model = CheckoutViewModel()..initialize();
    await wait();
    return model;
  }

  group('elegir la modalidad', () {
    test('con el express disponible se ofrece y trae recargo y demora',
        () async {
      final model = await ready();

      expect(model.showDeliveryChoice, isTrue);
      expect(model.expressOption!.surchargeAmount, 2350);
      expect(model.isExpress, isFalse);
      verify(history.deliveryOptions('a1')).called(1);
      model.dispose();
    });

    test('si la distribuidora no lo ofrece (disabled) no hay nada que elegir',
        () async {
      stubOptions(const DeliveryOption(
          mode: DeliveryMode.express, available: false, reason: 'disabled'));

      final model = await ready();

      expect(model.showDeliveryChoice, isFalse);
      model.dispose();
    });

    test('si la consulta falla no se ofrece el express y sigue el común',
        () async {
      when(history.deliveryOptions(any))
          .thenAnswer((_) async => const ApiResult.fail('Sin conexión.'));

      final model = await ready();

      expect(model.showDeliveryChoice, isFalse);
      model.selectTimeSlot('s1');
      await wait();
      expect(model.canConfirmOrder, isTrue);
      model.dispose();
    });

    test('no disponible: se ve el motivo y no se puede elegir', () async {
      stubOptions(_expressOff);
      final model = await ready();

      expect(model.showDeliveryChoice, isTrue);
      expect(model.expressOption!.unavailableText,
          'No hay un repartidor en moto disponible cerca.');
      model.setDeliveryMode(DeliveryMode.express);

      expect(model.isExpress, isFalse);
      model.dispose();
    });

    test('elegir express cotiza con la modalidad y no pide franja', () async {
      final model = await ready();
      expect(model.canConfirmOrder, isFalse); // común: falta la franja

      model.setDeliveryMode(DeliveryMode.express);
      expect(model.quote, isNull); // recotiza
      await wait();

      expect(quotedModes.last, DeliveryMode.express);
      expect(model.quote!.expressSurcharge, 2350);
      expect(model.quote!.total, 4350);
      expect(model.canConfirmOrder, isTrue);
      model.dispose();
    });

    test('volver a normal vuelve a pedir la franja', () async {
      final model = await ready();
      model.setDeliveryMode(DeliveryMode.express);
      await wait();
      model.setDeliveryMode(DeliveryMode.standard);
      await wait();

      expect(quotedModes.last, DeliveryMode.standard);
      expect(model.quote!.total, 2000);
      expect(model.canConfirmOrder, isFalse);
      model.dispose();
    });
  });

  group('el express deja de estar disponible', () {
    test('la cotización lo rechaza: vuelve al común con el motivo', () async {
      final model = await ready();
      model.setDeliveryMode(DeliveryMode.express);
      when(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              deliveryMode: DeliveryMode.express))
          .thenAnswer((_) async => const QuoteOutcome.failed(
              'El servicio express está fuera de horario.',
              retryable: false,
              expressUnavailableReason: 'out_of_hours'));
      stubOptions(const DeliveryOption(
          mode: DeliveryMode.express,
          available: false,
          reason: 'out_of_hours'));
      await wait(80);

      expect(model.isExpress, isFalse);
      expect(
          model.deliveryNotice, 'El servicio express está fuera de horario.');
      expect(model.quote!.deliveryMode, DeliveryMode.standard);
      expect(model.expressOption!.available, isFalse);
      model.dispose();
    });

    test('al confirmar (409): no crea nada, avisa y vuelve al común', () async {
      final model = await ready();
      model.setDeliveryMode(DeliveryMode.express);
      await wait();
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              deliveryMode: anyNamed('deliveryMode'),
              receiver: anyNamed('receiver')))
          .thenAnswer((_) async => const CreateOrderResult(
              success: false,
              retryable: false,
              message: 'El servicio express está fuera de horario.',
              expressUnavailableReason: 'out_of_hours'));
      stubOptions(const DeliveryOption(
          mode: DeliveryMode.express,
          available: false,
          reason: 'out_of_hours'));

      await model.confirmOrder();
      await wait();

      final shown = verify(dialogs.showDialog(
        title: 'El express ya no está disponible',
        description: captureAnyNamed('description'),
        buttonTitle: 'Aceptar',
      )).captured.single as String;
      expect(shown, contains('fuera de horario'));
      verifyNever(nav.replaceWith<dynamic>(
        Routes.orderTrackingView,
        arguments: anyNamed('arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      ));
      expect(model.isExpress, isFalse);
      expect(model.deliveryNotice, contains('fuera de horario'));
      expect(model.isBusy, isFalse);
      model.dispose();
    });
  });

  group('confirmar', () {
    void stubCreate() {
      when(history.createOrder(any,
              timeSlotId: anyNamed('timeSlotId'),
              fromCart: anyNamed('fromCart'),
              deliveryMode: anyNamed('deliveryMode'),
              receiver: anyNamed('receiver')))
          .thenAnswer((_) async =>
              CreateOrderResult(success: true, order: order(total: 4350)));
    }

    test('express: sin franja y con la modalidad', () async {
      stubCreate();
      final model = await ready();
      model.setDeliveryMode(DeliveryMode.express);
      await wait();

      await model.confirmOrder();

      final call = verify(history.createOrder(captureAny,
          timeSlotId: captureAnyNamed('timeSlotId'),
          fromCart: true,
          deliveryMode: captureAnyNamed('deliveryMode'),
          receiver: captureAnyNamed('receiver')));
      expect(call.captured[1], isNull);
      expect(call.captured[2], DeliveryMode.express);
      expect(call.captured[3], isNull);
      expect((call.captured[0] as Order).deliveryWindowStart, isNull);
      model.dispose();
    });

    test('común: lleva la franja elegida', () async {
      stubCreate();
      final model = await ready();
      model.selectTimeSlot('s1');
      await wait();

      await model.confirmOrder();

      final call = verify(history.createOrder(any,
          timeSlotId: captureAnyNamed('timeSlotId'),
          fromCart: true,
          deliveryMode: captureAnyNamed('deliveryMode'),
          receiver: anyNamed('receiver')));
      expect(call.captured, ['s1', DeliveryMode.standard]);
      model.dispose();
    });

    test('quién recibe se elige en la hoja y viaja en el alta', () async {
      stubCreate();
      const receptor = OrderReceiver(
          name: 'María Gómez', document: '30123456', relationship: 'vecina');
      final sheets = locator<BottomSheetService>() as MockBottomSheetService;
      when(sheets.showCustomSheet(
        variant: anyNamed('variant'),
        isScrollControlled: anyNamed('isScrollControlled'),
        enableDrag: anyNamed('enableDrag'),
        data: anyNamed('data'),
      )).thenAnswer(
          (_) async => SheetResponse(confirmed: true, data: receptor));
      final model = await ready();
      model.selectTimeSlot('s1');
      await wait();

      await model.editReceiver();
      expect(model.receiver!.name, 'María Gómez');
      await model.confirmOrder();

      final call = verify(history.createOrder(any,
          timeSlotId: anyNamed('timeSlotId'),
          fromCart: true,
          deliveryMode: anyNamed('deliveryMode'),
          receiver: captureAnyNamed('receiver')));
      expect(call.captured.single, receptor);
      model.dispose();
    });

    test('quitar a quien recibe: el alta va sin receptor', () async {
      stubCreate();
      final sheets = locator<BottomSheetService>() as MockBottomSheetService;
      when(sheets.showCustomSheet(
        variant: anyNamed('variant'),
        isScrollControlled: anyNamed('isScrollControlled'),
        enableDrag: anyNamed('enableDrag'),
        data: anyNamed('data'),
      )).thenAnswer((_) async => SheetResponse(
          confirmed: true,
          data: const OrderReceiver(
              name: 'A', document: '123456', relationship: 'x')));
      final model = await ready();
      await model.editReceiver();
      model.clearReceiver();

      expect(model.receiver, isNull);
      model.dispose();
    });
  });

  group('opciones de entrega: estado y aviso', () {
    test('una consulta fallida no se da por cargada: se reintenta', () async {
      when(history.deliveryOptions(any))
          .thenAnswer((_) async => const ApiResult.fail('Sin conexión.'));
      final model = await ready();
      expect(model.showDeliveryChoice, isFalse);

      stubOptions(_expressOk);
      await model.loadDeliveryOptions();

      expect(model.showDeliveryChoice, isTrue);
      verify(history.deliveryOptions('a1')).called(2);
      model.dispose();
    });

    test('el aviso se borra cuando el express vuelve a estar disponible',
        () async {
      final model = await ready();
      model.setDeliveryMode(DeliveryMode.express);
      stubOptions(const DeliveryOption(
          mode: DeliveryMode.express,
          available: false,
          reason: 'out_of_hours'));
      await model.loadDeliveryOptions(force: true);
      expect(model.deliveryNotice, isNotNull);
      expect(model.isExpress, isFalse);

      stubOptions(_expressOk);
      await model.loadDeliveryOptions(force: true);

      expect(model.deliveryNotice, isNull);
      model.dispose();
    });
  });
}
