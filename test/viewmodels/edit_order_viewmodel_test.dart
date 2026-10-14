import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/ui/views/edit_order/edit_order_viewmodel.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

const _tomado =
    'El pedido ya fue tomado por un repartidor: no se puede modificar';
const _sena = 'El total no puede quedar por debajo de la seña ya pagada';

void main() {
  late MockHistoryService history;
  late MockDialogService dialogs;
  late MockNavigationService nav;
  late List<Order> quoted;

  Future<void> wait([int ms = 30]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Order original() => order(
        items: [OrderItem(cylinder: cylinder(price: 1000), quantity: 2)],
        address: addr('a1', 'Mitre 100'),
      ).copyWith(
        deliveryWindowStart: '08:00:00',
        deliveryWindowEnd: '12:00:00',
        customerNotes: 'timbre',
      );

  QuoteOutcome byBack(Order o) {
    final qty = o.items.fold<int>(0, (n, i) => n + i.quantity);
    return backQuote(
      qty: qty,
      unit: 900,
      zoneSurcharge: 50,
      zoneName: 'Centro',
      paymentSurcharge: o.paymentMethod == PaymentMethod.cash ? 0 : 180,
    );
  }

  setUp(() {
    registerServices();
    EditOrderViewModel.quoteDebounce = const Duration(milliseconds: 10);
    EditOrderViewModel.now = () => DateTime(2026, 10, 14, 10);
    quoted = [];
    history = locator<HistoryService>() as MockHistoryService;
    dialogs = locator<DialogService>() as MockDialogService;
    nav = locator<NavigationService>() as MockNavigationService;
    when(history.quoteOrder(any,
            timeSlotId: anyNamed('timeSlotId'), orderId: anyNamed('orderId')))
        .thenAnswer((i) async {
      final o = i.positionalArguments.first as Order;
      quoted.add(o);
      return byBack(o);
    });
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.customer)
        .thenReturn(customerWith([addr('a1', 'Mitre 100', primary: true)]));
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenAnswer((_) async => [
          cylinder(price: 1000),
          cylinder(id: 'g2', price: 2000),
        ]);
    final slots = locator<TimeSlotService>() as MockTimeSlotService;
    when(slots.availabilityFor(any)).thenAnswer((_) async => const [
          TimeSlotAvailability(
              timeSlotId: 's1',
              name: 'Mañana',
              startTime: '08:00:00',
              endTime: '12:00:00',
              remaining: 0),
          TimeSlotAvailability(
              timeSlotId: 's2',
              name: 'Tarde',
              startTime: '16:00:00',
              endTime: '20:00:00',
              remaining: 5),
        ]);
  });

  tearDown(() {
    EditOrderViewModel.quoteDebounce = const Duration(milliseconds: 400);
    EditOrderViewModel.now = DateTime.now;
    locator.reset();
  });

  /// Pedido que ya tenía fecha agendada (hoy) y la franja de la mañana.
  const agendado = OrderBreakdown(total: 1000, scheduledDate: '2026-10-14');

  Future<EditOrderViewModel> ready([OrderBreakdown? b = agendado]) async {
    final m = EditOrderViewModel(original: original(), breakdown: b);
    await m.initialize();
    await wait();
    return m;
  }

  void stubUpdate(UpdateOrderResult result) {
    when(history.updateOrder(any, any, timeSlotId: anyNamed('timeSlotId')))
        .thenAnswer((_) async => result);
  }

  group('arranque', () {
    test('parte del pedido: cantidades, dirección, notas, pago y franja',
        () async {
      final m = await ready();

      expect(m.quantityOf('g1'), 2);
      expect(m.quantityOf('g2'), 0);
      expect(m.address!.streetName, 'Mitre 100');
      expect(m.notesController.text, 'timbre');
      expect(m.paymentMethod, PaymentMethod.cash);
      // La franja que ya tenía, aunque hoy figure llena (el cupo es el suyo).
      expect(m.selectedTimeSlotId, 's1');
      expect(m.canPickSlot(m.timeSlots.first), isTrue);
      expect(m.canSave, isFalse); // nada cambió: no hay qué guardar
      m.dispose();
    });

    test('el total sale de la cotización del back, no de una cuenta local',
        () async {
      final m = await ready();

      expect(m.quote!.total, 1850);
      expect(m.quote!.zoneSurcharge, 50);
      expect(quoted.last.items.single.quantity, 2);
      // Cotización de edición: el back cuenta lo que el pedido ya ocupa.
      verify(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'), orderId: 'o1'))
          .called(greaterThan(0));
      verifyNever(history.quoteOrder(any,
          timeSlotId: anyNamed('timeSlotId'), orderId: null));
      m.dispose();
    });

    test('toma la fecha agendada del pedido; si ya pasó, hoy', () async {
      final futura = await ready(
          const OrderBreakdown(total: 1000, scheduledDate: '2026-10-20'));
      expect(futura.selectedDate, DateTime(2026, 10, 20));
      futura.dispose();

      final pasada = await ready(
          const OrderBreakdown(total: 1000, scheduledDate: '2026-10-01'));
      expect(pasada.selectedDate, DateTime(2026, 10, 14));
      pasada.dispose();
    });

    test('si el catálogo no carga, muestra el error y se puede reintentar',
        () async {
      final gas = locator<GasCylinderService>() as MockGasCylinderService;
      when(gas.getGasCylinders()).thenThrow(Exception('sin red'));
      final m = EditOrderViewModel(original: original());

      await m.initialize();

      expect(m.loadError, isNotNull);
      expect(m.canSave, isFalse);
      m.dispose();
    });
  });

  group('editar', () {
    test('cambiar una cantidad recotiza con lo nuevo', () async {
      final m = await ready();

      m.changeQuantity(m.cylinders[1], 1);
      expect(m.quote, isNull);
      await wait();

      expect(quoted.last.items.map((i) => i.quantity).toList(), [2, 1]);
      expect(m.quote!.total, 2750);
      m.dispose();
    });

    test('no baja de cero y sin garrafas no se puede guardar', () async {
      final m = await ready();

      m.changeQuantity(m.cylinders.first, -5);
      expect(m.quantityOf('g1'), 2);
      m.changeQuantity(m.cylinders.first, -2);
      m.changeQuantity(m.cylinders.first, -1);
      await wait();

      expect(m.quantityOf('g1'), 0);
      expect(m.canSave, isFalse);
      m.dispose();
    });

    test('no se puede pasar a Mercado Pago; transferencia sí y suma recargo',
        () async {
      final m = await ready();

      m.setPaymentMethod(PaymentMethod.mercadoPago);
      expect(m.paymentMethod, PaymentMethod.cash);

      m.setPaymentMethod(PaymentMethod.online);
      await wait();
      expect(m.quote!.paymentSurcharge, 180);
      expect(m.quote!.total, 2030);
      m.dispose();
    });

    test('varios cambios seguidos piden una sola cotización', () async {
      EditOrderViewModel.quoteDebounce = const Duration(milliseconds: 60);
      final m = await ready();
      final before = quoted.length;

      m.changeQuantity(m.cylinders.first, 1);
      m.changeQuantity(m.cylinders.first, 1);
      m.changeQuantity(m.cylinders.first, 1);
      await wait(150);

      expect(quoted.length - before, 1);
      expect(quoted.last.items.single.quantity, 5);
      m.dispose();
    });

    test('una respuesta vieja no pisa a la última', () async {
      final first = Completer<QuoteOutcome>();
      var calls = 0;
      when(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'), orderId: anyNamed('orderId')))
          .thenAnswer((i) {
        if (++calls == 1) return first.future;
        return Future.value(byBack(i.positionalArguments.first as Order));
      });
      final m = EditOrderViewModel(original: original());
      await m.initialize();
      await wait(); // sale la primera y queda colgada
      m.setPaymentMethod(PaymentMethod.online);
      await wait();

      first.complete(backQuote(unit: 1));
      await wait();

      expect(m.quote!.paymentSurcharge, 180);
      m.dispose();
    });

    test('si el back rechaza la cotización, muestra su mensaje y no guarda',
        () async {
      when(history.quoteOrder(any,
              timeSlotId: anyNamed('timeSlotId'), orderId: anyNamed('orderId')))
          .thenAnswer((_) async => const QuoteOutcome.failed(
              'Sin stock de Garrafa 10kg',
              retryable: false));
      final m = EditOrderViewModel(original: original());
      await m.initialize();
      await wait();

      expect(m.quote, isNull);
      expect(m.quoteError, 'Sin stock de Garrafa 10kg');
      expect(m.canSave, isFalse);
      m.dispose();
    });
  });

  group('notas', () {
    Order sinNotas() => original().copyWith(customerNotes: null);

    Future<EditOrderViewModel> listo(Order o) async {
      final m = EditOrderViewModel(original: o, breakdown: agendado);
      await m.initialize();
      await wait();
      return m;
    }

    test('sin ningún cambio no se puede guardar', () async {
      final m = await ready();
      expect(m.hasChanges, isFalse);
      expect(m.canSave, isFalse);
      m.dispose();
    });

    test('null y vacío son lo mismo: no cuenta como cambio', () async {
      final m = await listo(sinNotas());
      m.notesController.text = '  ';
      expect(m.hasChanges, isFalse);
      m.dispose();
    });

    test('sin cambiar las notas no se mandan; cambiadas, sí', () async {
      stubUpdate(const UpdateOrderResult(success: true));
      final m = await listo(sinNotas());
      m.changeQuantity(m.cylinders[1], 1);
      await wait();

      await m.save();

      final sent = verify(history.updateOrder('o1', captureAny,
              timeSlotId: anyNamed('timeSlotId')))
          .captured
          .single as Order;
      expect(sent.customerNotes, isNull);
      m.dispose();

      final n = await listo(sinNotas());
      n.notesController.text = 'portón';
      await n.save();
      final sent2 = verify(history.updateOrder('o1', captureAny,
              timeSlotId: anyNamed('timeSlotId')))
          .captured
          .single as Order;
      expect(sent2.customerNotes, 'portón');
      n.dispose();
    });

    test('vaciar notas que existían es un cambio y se manda vacío', () async {
      stubUpdate(const UpdateOrderResult(success: true));
      final m = await ready();
      m.notesController.text = '';
      expect(m.canSave, isTrue);

      await m.save();

      final sent = verify(history.updateOrder('o1', captureAny,
              timeSlotId: anyNamed('timeSlotId')))
          .captured
          .single as Order;
      expect(sent.customerNotes, '');
      m.dispose();
    });
  });

  group('fecha y franja', () {
    test('sin fecha agendada: no manda fecha ni franja salvo que se elijan',
        () async {
      stubUpdate(const UpdateOrderResult(success: true));
      final m = await ready(null);
      expect(m.formattedDate, 'Sin fecha agendada');
      expect(m.selectedTimeSlotId, isNull);
      m.changeQuantity(m.cylinders[1], 1);
      await wait();

      await m.save();

      final sent = verify(history.updateOrder('o1', captureAny,
              timeSlotId: captureAnyNamed('timeSlotId')))
          .captured;
      expect((sent[0] as Order).requestedDeliveryDate, isNull);
      expect(sent[1], isNull);
      expect(quoted.last.requestedDeliveryDate, isNull);
      m.dispose();
    });

    test('sin fecha agendada, elegir una franja manda fecha y franja',
        () async {
      stubUpdate(const UpdateOrderResult(success: true));
      final m = await ready(null);

      m.selectTimeSlot('s2');
      await wait();
      expect(m.canSave, isTrue);
      await m.save();

      final sent = verify(history.updateOrder('o1', captureAny,
              timeSlotId: captureAnyNamed('timeSlotId')))
          .captured;
      expect((sent[0] as Order).requestedDeliveryDate, DateTime(2026, 10, 14));
      expect(sent[1], 's2');
      m.dispose();
    });

    test('la franja original llena sólo se mantiene el mismo día', () async {
      final m = await ready();
      expect(m.selectedTimeSlotId, 's1');
      expect(m.canPickSlot(m.timeSlots.first), isTrue);

      // Otro día: la franja de la mañana sigue figurando llena.
      await m.changeDate(DateTime(2026, 10, 15));

      expect(m.canPickSlot(m.timeSlots.first), isFalse);
      expect(m.selectedTimeSlotId, isNull);
      expect(m.canSave, isFalse); // falta elegir franja
      m.dispose();
    });

    test('una carga de franjas vieja no pisa a la última', () async {
      final slots = locator<TimeSlotService>() as MockTimeSlotService;
      final first = Completer<List<TimeSlotAvailability>>();
      var calls = 0;
      when(slots.availabilityFor(any)).thenAnswer((_) {
        if (++calls == 1) return first.future;
        return Future.value(const [
          TimeSlotAvailability(
              timeSlotId: 'nueva',
              name: 'Noche',
              startTime: '20:00:00',
              endTime: '22:00:00',
              remaining: 3),
        ]);
      });
      final m = EditOrderViewModel(original: original(), breakdown: agendado);
      final init = m.initialize(); // la primera carga queda colgada
      await wait();
      await m.changeDate(DateTime(2026, 10, 15));

      first.complete(const [
        TimeSlotAvailability(
            timeSlotId: 'vieja',
            name: 'Mañana',
            startTime: '08:00:00',
            endTime: '12:00:00',
            remaining: 9),
      ]);
      await init;
      await wait();

      expect(m.timeSlots.map((s) => s.timeSlotId), ['nueva']);
      expect(m.loadingTimeSlots, isFalse);
      m.dispose();
    });
  });

  group('guardar', () {
    test(
        'manda lo editado con la franja y muestra el total que devuelve el PATCH',
        () async {
      stubUpdate(UpdateOrderResult(
          success: true, order: order(id: 'o1', total: 2750)));
      final m = await ready();
      m.changeQuantity(m.cylinders[1], 1);
      m.notesController.text = 'portón verde';
      m.selectTimeSlot('s2');
      await wait();

      await m.save();

      final sent = verify(history.updateOrder('o1', captureAny,
              timeSlotId: captureAnyNamed('timeSlotId')))
          .captured;
      final draft = sent[0] as Order;
      expect(draft.items.map((i) => (i.cylinder.id, i.quantity)).toList(),
          [('g1', 2), ('g2', 1)]);
      expect(draft.customerNotes, 'portón verde');
      expect(draft.address!.addressId, 'a1');
      expect(sent[1], 's2');
      verify(dialogs.showDialog(
        title: 'Pedido modificado',
        description: argThat(contains('\$2.750'), named: 'description'),
        buttonTitle: 'Aceptar',
      )).called(1);
      verify(nav.back(result: true)).called(1);
      m.dispose();
    });

    test('mientras guarda no se puede cambiar nada', () async {
      final gate = Completer<UpdateOrderResult>();
      when(history.updateOrder(any, any, timeSlotId: anyNamed('timeSlotId')))
          .thenAnswer((_) => gate.future);
      final m = await ready();
      m.notesController.text = 'otra';

      final f = m.save();
      expect(m.saving, isTrue);
      m.changeQuantity(m.cylinders.first, 1);
      m.setPaymentMethod(PaymentMethod.online);
      m.selectTimeSlot('s2');
      expect(m.quantityOf('g1'), 2);
      expect(m.paymentMethod, PaymentMethod.cash);
      expect(m.canSave, isFalse);
      gate.complete(const UpdateOrderResult(success: true));
      await f;

      verify(history.updateOrder(any, any, timeSlotId: anyNamed('timeSlotId')))
          .called(1);
      m.dispose();
    });

    test(
        '409 porque lo tomó un repartidor: muestra el mensaje del back, relee '
        'y vuelve al detalle', () async {
      stubUpdate(const UpdateOrderResult(
          success: false, rejected: true, message: _tomado));
      when(history.fetchOrderDetail('o1')).thenAnswer(
          (_) async => OrderDetail(order(status: OrderStatus.accepted), null));
      final m = await ready();
      m.notesController.text = 'otra';

      await m.save();

      verify(dialogs.showDialog(
        title: 'No pudimos modificar tu pedido',
        description: _tomado,
        buttonTitle: 'Aceptar',
      )).called(1);
      verify(history.fetchOrderDetail('o1')).called(1);
      verify(nav.back(result: false)).called(1);
      expect(m.saving, isFalse);
      m.dispose();
    });

    test('409 por la seña: muestra el mensaje y se queda para corregir',
        () async {
      stubUpdate(const UpdateOrderResult(
          success: false, rejected: true, message: _sena));
      when(history.fetchOrderDetail('o1'))
          .thenAnswer((_) async => OrderDetail(order(), null));
      final m = await ready();
      m.notesController.text = 'otra';

      await m.save();

      verify(dialogs.showDialog(
        title: 'No pudimos modificar tu pedido',
        description: _sena,
        buttonTitle: 'Aceptar',
      )).called(1);
      verifyNever(nav.back(result: anyNamed('result')));
      expect(m.saving, isFalse);
      m.dispose();
    });

    test('404 porque el pedido ya no existe: relee y vuelve al detalle',
        () async {
      stubUpdate(const UpdateOrderResult(
          success: false,
          rejected: true,
          message: 'Este pedido ya no está disponible.'));
      when(history.fetchOrderDetail('o1'))
          .thenAnswer((_) async => throw orderGoneFailure);
      final m = await ready();
      m.notesController.text = 'otra';

      await m.save();

      verify(history.fetchOrderDetail('o1')).called(1);
      verify(nav.back(result: false)).called(1);
      m.dispose();
    });

    test('404 "Dirección no encontrada": muestra el mensaje y se queda',
        () async {
      stubUpdate(const UpdateOrderResult(
          success: false, message: 'Dirección no encontrada'));
      final m = await ready();
      m.notesController.text = 'otra';

      await m.save();

      verify(dialogs.showDialog(
        title: 'No pudimos modificar tu pedido',
        description: 'Dirección no encontrada',
        buttonTitle: 'Aceptar',
      )).called(1);
      verifyNever(history.fetchOrderDetail(any));
      verifyNever(nav.back(result: anyNamed('result')));
      m.dispose();
    });

    test('falla de red: avisa y se queda para reintentar', () async {
      stubUpdate(const UpdateOrderResult(
          success: false,
          retryable: true,
          message: 'Sin conexión. Revisá tu internet.'));
      final m = await ready();
      m.notesController.text = 'otra';

      await m.save();

      verify(dialogs.showDialog(
        title: 'No pudimos modificar tu pedido',
        description: 'Sin conexión. Revisá tu internet.',
        buttonTitle: 'Aceptar',
      )).called(1);
      verifyNever(history.fetchOrderDetail(any));
      verifyNever(nav.back(result: anyNamed('result')));
      expect(m.canSave, isTrue);
      m.dispose();
    });

    test('422 de la clave: avisa que puede haberse guardado y vuelve',
        () async {
      stubUpdate(const UpdateOrderResult(
          success: false,
          idempotencyConflict: true,
          message: kOrderMaybeEditedText));
      when(history.fetchOrderDetail('o1'))
          .thenAnswer((_) async => OrderDetail(order(), null));
      final m = await ready();
      m.notesController.text = 'otra';

      await m.save();

      verify(dialogs.showDialog(
        title: 'Revisá tu pedido',
        description: kOrderMaybeEditedText,
        buttonTitle: 'Aceptar',
      )).called(1);
      verify(history.fetchOrderDetail('o1')).called(1);
      verify(nav.back(result: false)).called(1);
      m.dispose();
    });

    test('sin cotización vigente no manda nada', () async {
      final m = EditOrderViewModel(original: original());
      await m.initialize(); // todavía cotizando

      await m.save();

      verifyNever(
          history.updateOrder(any, any, timeSlotId: anyNamed('timeSlotId')));
      await wait();
      m.dispose();
    });
  });
}
