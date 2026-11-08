import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

/// Lo que responde `POST /orders/quote` (docs/PEDIDOS.md del back).
const _respuesta = {
  'items': [
    {
      'gasCylinderId': 'g1',
      'title': 'Garrafa 10kg',
      'quantity': 3,
      'unitPrice': 8500,
      'subtotal': 25500,
    }
  ],
  'subtotal': 25500,
  'zone': {
    'coverageZoneId': 'z1',
    'name': 'Centro',
    'type': 'fixed',
    'value': 500,
    'amount': 500,
  },
  'zoneSurcharge': 500,
  'paymentMethod': 'mercadopago',
  'paymentSurcharge': 2600,
  'deposit': 0,
  'total': 28600,
  'balance': 28600,
};

void main() {
  late HistoryService history;

  Order pedido(PaymentMethod method) => order(
        address: addr('a1', 'Mitre 100'),
        items: [OrderItem(cylinder: cylinder(), quantity: 3)],
      ).copyWith(paymentMethod: method);

  setUp(() {
    registerServices();
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    history = HistoryService();
  });
  tearDown(() => locator.reset());

  test(
      'pide POST /orders/quote con el medio de pago del back y muestra lo que '
      'devuelve', () async {
    final log = fakeHttp((_) => const FakeReply(200, _respuesta));

    final outcome = await history.quoteOrder(pedido(PaymentMethod.mercadoPago));

    expect(log.single.method, 'POST');
    expect(log.single.path, 'orders/quote');
    final body = log.single.body as Map;
    expect(body['paymentMethod'], 'mercadopago');
    expect(body['addressId'], 'a1');
    expect(body.containsKey('notificationToken'), isFalse);
    expect(outcome.ok, isTrue);
    final quote = outcome.quote!;
    expect(quote.total, 28600);
    expect(quote.zoneSurcharge, 500);
    expect(quote.zoneName, 'Centro');
    expect(quote.paymentSurcharge, 2600);
    expect(quote.lineFor('g1')!.unitPrice, 8500);
  });

  test(
      'un 400 de negocio (sin stock, fuera de zona) llega con su mensaje y '
      'no se reintenta', () async {
    fakeHttp((_) => const FakeReply(400, {
          'statusCode': 400,
          'message': 'La dirección está fuera de la zona de cobertura',
        }));

    final outcome = await history.quoteOrder(pedido(PaymentMethod.cash));

    expect(outcome.ok, isFalse);
    expect(outcome.message, 'La dirección está fuera de la zona de cobertura');
    expect(outcome.retryable, isFalse);
  });

  test(
      '400 porque la distribuidora no cargó el precio del envase: llega tal '
      'cual y no se reintenta', () async {
    const sinPrecio = 'La distribuidora todavía no cargó el precio del envase '
        'de Garrafa 10kg: no se puede tomar el pedido';
    fakeHttp((_) => const FakeReply(400, {
          'statusCode': 400,
          'message': sinPrecio,
          'error': 'Bad Request',
        }));

    final outcome = await history.quoteOrder(pedido(PaymentMethod.cash));

    expect(outcome.ok, isFalse);
    expect(outcome.message, sinPrecio);
    expect(outcome.retryable, isFalse);
  });

  test('sin red, 429 y 5xx se pueden reintentar con texto propio', () async {
    for (final reply in [
      const FakeReply.networkError(),
      const FakeReply(429, {'message': 'Too Many Requests'}),
      const FakeReply(503, {'message': 'Service Unavailable'}),
    ]) {
      fakeHttp((_) => reply);
      final outcome = await history.quoteOrder(pedido(PaymentMethod.cash));
      expect(outcome.ok, isFalse);
      expect(outcome.retryable, isTrue);
      expect(outcome.message, isNot(contains('Unavailable')));
    }
  });

  test('una respuesta sin total no se convierte en un precio inventado',
      () async {
    fakeHttp((_) => const FakeReply(200, {'items': []}));

    final outcome = await history.quoteOrder(pedido(PaymentMethod.cash));

    expect(outcome.ok, isFalse);
    expect(OrderQuote.fromJson({'subtotal': 10}), isNull);
  });

  group('GET /orders/:id', () {
    test('404 y 410 no se reintentan: falla definitiva con mensaje claro',
        () async {
      for (final status in [404, 410]) {
        fakeHttp((_) => FakeReply(status, {'message': 'x'}));
        await expectLater(
            history.fetchOrder('o1'),
            throwsA(isA<LoadFailure>()
                .having((f) => f.retryable, 'retryable', isFalse)
                .having((f) => f.message, 'message', kOrderGoneText)));
      }
    });

    test('un 5xx sigue siendo reintentable (no es "ya no existe")', () async {
      fakeHttp((_) => const FakeReply(503, {'message': 'x'}));
      await expectLater(history.fetchOrder('o1'), throwsA(isA<DioException>()));
    });
  });

  group('desde el carrito -', () {
    test('la cotización manda fromCart y ningún ítem', () async {
      final log = fakeHttp((_) => const FakeReply(200, _respuesta));
      await history.quoteOrder(pedido(PaymentMethod.cash), fromCart: true);
      final body = log.single.body as Map;
      expect(body['fromCart'], isTrue);
      expect(body.containsKey('items'), isFalse);
      expect(body['addressId'], 'a1');
    });

    test('sin fromCart sigue mandando los ítems armados', () async {
      final log = fakeHttp((_) => const FakeReply(200, _respuesta));
      await history.quoteOrder(pedido(PaymentMethod.cash));
      final body = log.single.body as Map;
      expect(body.containsKey('fromCart'), isFalse);
      expect(body['items'], hasLength(1));
    });

    test('el alta manda fromCart sin ítems y sin borrar nada del carrito',
        () async {
      final log = fakeHttp((_) => const FakeReply(201, {
            'order_id': 'o9',
            'status': 'pending',
            'total_amount': 1000,
            'items': [],
          }));
      final r =
          await history.createOrder(pedido(PaymentMethod.cash), fromCart: true);
      expect(r.success, isTrue);
      final body = log.single.body as Map;
      expect(log.single.path, 'orders');
      expect(body['fromCart'], isTrue);
      expect(body.containsKey('items'), isFalse);
      // La app no toca /cart: el back lo vacía en la transacción del pedido.
      expect(log.where((r) => r.path.startsWith('cart')), isEmpty);
    });

    test('el 400 de carrito vacío o con ítems dados de baja se muestra',
        () async {
      fakeHttp((_) => const FakeReply(400,
          {'message': 'El carrito está vacío o tiene ítems no disponibles'}));
      final r =
          await history.createOrder(pedido(PaymentMethod.cash), fromCart: true);
      expect(r.success, isFalse);
      expect(r.message, contains('carrito'));
    });
  });
}
