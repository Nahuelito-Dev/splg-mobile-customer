import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/customer_service.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  setUp(() {
    registerServices();
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
  });
  tearDown(() => locator.reset());

  Future<void> crear(ClaimService s, {String detalle = 'Llegó tarde'}) =>
      s.createClaim(orderId: 'o1', reason: 'Demora', description: detalle);

  test('POST /claims manda Idempotency-Key', () async {
    final log = fakeHttp((_) => const FakeReply(201, {'claim_id': 'c1'}));

    final r = await ClaimService().createClaim(
        orderId: 'o1', reason: 'Demora', description: 'Llegó tarde');

    expect(r.ok, isTrue);
    expect(log.single.path, 'claims');
    expect(log.single.headers['Idempotency-Key'], isNotEmpty);
  });

  test('sin respuesta, 5xx, 429, 409 en curso y 422: misma clave al reintentar',
      () async {
    final respuestas = [
      const FakeReply.networkError(),
      const FakeReply(503, {'message': 'x'}),
      const FakeReply(429, {'message': 'x'}),
      const FakeReply(
          409, {'message': 'Request en curso con la misma Idempotency-Key'}),
      const FakeReply(422,
          {'message': 'Esa clave de idempotencia ya se usó con otros datos.'}),
      const FakeReply(201, {'claim_id': 'c1'}),
    ];
    var i = 0;
    final log = fakeHttp((_) => respuestas[i++]);
    final s = ClaimService();

    for (var n = 0; n < respuestas.length; n++) {
      await crear(s);
    }

    final claves = log.map((r) => r.headers['Idempotency-Key']).toSet();
    expect(claves, hasLength(1));
  });

  test('tras crearse o un rechazo de negocio, el próximo reclamo lleva otra',
      () async {
    final respuestas = [
      const FakeReply(201, {'claim_id': 'c1'}),
      const FakeReply(400, {'message': 'El pedido no está entregado'}),
      const FakeReply(201, {'claim_id': 'c2'}),
    ];
    var i = 0;
    final log = fakeHttp((_) => respuestas[i++]);
    final s = ClaimService();

    for (var n = 0; n < respuestas.length; n++) {
      await crear(s);
    }

    expect(log.map((r) => r.headers['Idempotency-Key']).toSet(), hasLength(3));
  });

  test('otro detalle es otro reclamo: otra clave', () async {
    final log = fakeHttp((_) => const FakeReply.networkError());
    final s = ClaimService();

    await crear(s, detalle: 'uno');
    await crear(s, detalle: 'dos');

    expect(log.map((r) => r.headers['Idempotency-Key']).toSet(), hasLength(2));
  });
}
