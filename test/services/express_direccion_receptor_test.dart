import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

const _orderJson = {
  'id': 'o1',
  'total_amount': 12350,
  'status': 'pending',
  'paymentMethod': 'cash',
  'deliveryMode': 'express',
  'expressSurchargeAmount': 2350,
  'delivery_address': {'address_id': 'a1', 'street': 'Mitre 100'},
  'order_items': [],
};

const _expressNoDisponible = {
  'statusCode': 409,
  'error': 'Conflict',
  'code': 'EXPRESS_NOT_AVAILABLE',
  'reason': 'out_of_hours',
  'message': 'Fuera del horario del servicio express',
};

void main() {
  late HistoryService history;

  Order pedido() => order(
        address: addr('a1', 'Mitre 100'),
        items: [OrderItem(cylinder: cylinder(), quantity: 2)],
      ).copyWith(requestedDeliveryDate: DateTime(2026, 10, 20));

  const receptor = OrderReceiver(
      name: 'María Gómez', document: '30123456', relationship: 'vecina');

  setUp(() {
    registerServices();
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    history = HistoryService();
  });
  tearDown(() => locator.reset());

  group('alta y cotización express', () {
    test('el express no se agenda: sin fecha ni franja, con deliveryMode', () {
      final log = fakeHttp((_) => const FakeReply(201, _orderJson));

      return history
          .createOrder(pedido(),
              timeSlotId: 's1', deliveryMode: DeliveryMode.express)
          .then((r) {
        final body = log.single.body as Map;
        expect(r.success, isTrue);
        expect(body['deliveryMode'], 'express');
        expect(body.containsKey('scheduledDate'), isFalse);
        expect(body.containsKey('timeSlotId'), isFalse);
      });
    });

    test('el reparto común sigue mandando fecha y franja, sin deliveryMode',
        () async {
      final log = fakeHttp((_) => const FakeReply(201, _orderJson));

      await history.createOrder(pedido(), timeSlotId: 's1');

      final body = log.single.body as Map;
      expect(body['scheduledDate'], '2026-10-20');
      expect(body['timeSlotId'], 's1');
      expect(body.containsKey('deliveryMode'), isFalse);
      expect(body.containsKey('receiver'), isFalse);
    });

    test('quién recibe viaja en el alta con los nombres del back', () async {
      final log = fakeHttp((_) => const FakeReply(201, _orderJson));

      await history.createOrder(pedido(), timeSlotId: 's1', receiver: receptor);

      expect((log.single.body as Map)['receiver'], {
        'receiverName': 'María Gómez',
        'receiverDocument': '30123456',
        'receiverRelationship': 'vecina',
      });
    });

    test('409 EXPRESS_NOT_AVAILABLE: no se creó nada y dice por qué', () async {
      fakeHttp((_) => const FakeReply(409, _expressNoDisponible));

      final r = await history.createOrder(pedido(),
          deliveryMode: DeliveryMode.express);

      expect(r.success, isFalse);
      expect(r.expressUnavailableReason, 'out_of_hours');
      expect(r.message, 'El servicio express está fuera de horario.');
      expect(r.retryable, isFalse);
    });

    test('un 409 que no es del express no lo parece', () async {
      fakeHttp((_) => const FakeReply(
          409, {'message': 'Stock insuficiente para Garrafa 10kg'}));

      final r = await history.createOrder(pedido());

      expect(r.expressUnavailableReason, isNull);
      expect(r.message, 'Stock insuficiente para Garrafa 10kg');
    });

    test('cotizar express: manda deliveryMode y lee el recargo', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            'items': [],
            'subtotal': 10000,
            'total': 12350,
            'deliveryMode': 'express',
            'expressSurcharge': 2350,
          }));

      final o = await history.quoteOrder(pedido(),
          fromCart: true, deliveryMode: DeliveryMode.express);

      final body = log.single.body as Map;
      expect(body['deliveryMode'], 'express');
      expect(body.containsKey('scheduledDate'), isFalse);
      expect(body.containsKey('receiver'), isFalse);
      expect(o.quote!.expressSurcharge, 2350);
      expect(o.quote!.deliveryMode, DeliveryMode.express);
      expect(o.quote!.total, 12350);
    });

    test('cotizar express no disponible: motivo en castellano', () async {
      fakeHttp((_) => const FakeReply(409, _expressNoDisponible));

      final o = await history.quoteOrder(pedido(),
          deliveryMode: DeliveryMode.express);

      expect(o.ok, isFalse);
      expect(o.expressUnavailableReason, 'out_of_hours');
      expect(o.message, 'El servicio express está fuera de horario.');
    });
  });

  group('GET /orders/delivery-options', () {
    test('pide por dirección y lee las modalidades', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            'addressId': 'a1',
            'options': [
              {
                'mode': 'express',
                'available': true,
                'surchargeAmount': 2350,
                'estimatedMinutes': 45
              },
            ],
          }));

      final r = await history.deliveryOptions('a1');

      expect(log.single.method, 'GET');
      expect(log.single.path, 'orders/delivery-options?addressId=a1');
      expect(r.ok, isTrue);
      expect(r.data!.optionFor(DeliveryMode.express)!.surchargeAmount, 2350);
    });

    test('un error vuelve con texto y sin opciones', () async {
      fakeHttp(
          (_) => const FakeReply(404, {'message': 'Dirección no encontrada'}));

      final r = await history.deliveryOptions('zzz');

      expect(r.ok, isFalse);
      expect(r.data, isNull);
      expect(r.message, isNotEmpty);
    });
  });

  group('PATCH /orders/:id/address', () {
    test('manda addressId y motivo con Idempotency-Key y devuelve el pedido',
        () async {
      final log = fakeHttp((_) => FakeReply(200, {
            ..._orderJson,
            'deliveryMode': 'standard',
            'total_amount': 2500,
          }));

      final r =
          await history.changeOrderAddress('o1', 'a2', reason: ' me mudo ');

      expect(log.single.method, 'PATCH');
      expect(log.single.path, 'orders/o1/address');
      expect(log.single.body, {'addressId': 'a2', 'reason': 'me mudo'});
      expect(log.single.headers['Idempotency-Key'], isNotEmpty);
      expect(r.success, isTrue);
      expect(r.order!.total, 2500);
    });

    test('sin motivo no lo manda', () async {
      final log = fakeHttp((_) => const FakeReply(200, _orderJson));
      await history.changeOrderAddress('o1', 'a2');
      expect(log.single.body, {'addressId': 'a2'});
    });

    for (final (status, message) in [
      (
        409,
        'El pedido ya salió o fue entregado: no se puede cambiar la dirección'
      ),
      (
        409,
        'El recargo de la zona nueva es distinto del original y el pedido es de pago en línea: cancelalo y hacelo de nuevo con la dirección que querés'
      ),
      (
        409,
        'Un pedido express no cambia de dirección: la cobertura, el horario y la moto se evaluaron con la dirección original. Cancelalo y creá uno nuevo'
      ),
      (
        400,
        'La dirección está fuera de la zona de cobertura de la distribuidora'
      ),
      (404, 'Dirección no encontrada'),
    ]) {
      test('$status "${message.substring(0, 20)}…": se muestra el del back',
          () async {
        fakeHttp((_) => FakeReply(status, {'message': message}));

        final r = await history.changeOrderAddress('o1', 'a2');

        expect(r.success, isFalse);
        expect(r.message, message);
        expect(r.retryable, isFalse);
      });
    }

    test('un 409 de estado marca el pedido para releerlo', () async {
      fakeHttp((_) => const FakeReply(409, {
            'message':
                'El pedido ya salió o fue entregado: no se puede cambiar la dirección'
          }));
      expect((await history.changeOrderAddress('o1', 'a2')).rejected, isTrue);
    });

    test('red caída: reintenta con la misma clave; otra dirección, otra clave',
        () async {
      final keys = <String>[];
      var n = 0;
      fakeHttp((r) {
        keys.add(r.headers['Idempotency-Key'] as String);
        return n++ == 0
            ? const FakeReply.networkError()
            : const FakeReply(200, _orderJson);
      });

      final first = await history.changeOrderAddress('o1', 'a2');
      expect(first.success, isFalse);
      expect(first.retryable, isTrue);
      await history.changeOrderAddress('o1', 'a2');
      await history.changeOrderAddress('o1', 'a3');

      expect(keys[1], keys[0]);
      expect(keys[2], isNot(keys[0]));
    });
  });

  group('PATCH /orders/:id/receiver', () {
    test('manda los tres datos y devuelve el pedido', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            ..._orderJson,
            'receiver': {
              'name': 'María Gómez',
              'document': '30123456',
              'relationship': 'vecina'
            },
          }));

      final r = await history.setOrderReceiver('o1', receptor);

      expect(log.single.method, 'PATCH');
      expect(log.single.path, 'orders/o1/receiver');
      expect(log.single.body, receptor.toJson());
      expect(log.single.headers['Idempotency-Key'], isNotEmpty);
      expect(r.success, isTrue);
    });

    test('409 ya entregado: el mensaje del back', () async {
      const m =
          'El pedido ya fue entregado: no se puede indicar quién lo recibe';
      fakeHttp((_) => const FakeReply(409, {'message': m}));

      final r = await history.setOrderReceiver('o1', receptor);

      expect(r.success, isFalse);
      expect(r.message, m);
    });

    test('400 de validación: texto del back en castellano', () async {
      const m =
          'receiverDocument: formato inválido (DNI, CUIT/CUIL o pasaporte: de 6 a 15 letras o dígitos)';
      fakeHttp((_) => const FakeReply(400, {
            'message': [m]
          }));

      final r = await history.setOrderReceiver('o1', receptor);

      expect(r.message, m);
    });
  });
}
