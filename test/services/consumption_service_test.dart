import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/consumption_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

import '../helpers/fake_http.dart';
import '../helpers/test_helpers.dart';

const _outOfRange = {
  'message': 'El consumo declarado (900 kg por mes) está fuera del rango '
      'razonable (5 a 500 kg por mes): confirmalo enviando confirmOutOfRange: true',
};

void main() {
  late ConsumptionService service;

  setUp(() {
    registerServices();
    service = ConsumptionService(tokenReader: () async => 'tok');
  });
  tearDown(() => locator.reset());

  group('ConsumptionServiceTest -', () {
    test('lee lo declarado y la próxima recompra (CU-144)', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            'cylinderTypeId': 't1',
            'cylinderType': '10kg',
            'avgMonthlyConsumptionKg': 20,
            'nextRepurchaseEstimateAt': '2026-11-01T12:00:00.000Z',
          }));
      final r = await service.fetch();
      expect(log.single.method, 'GET');
      expect(log.single.path, 'customers/me/consumption');
      expect(r.ok, isTrue);
      expect(r.data!.declared, isTrue);
      expect(r.data!.avgMonthlyConsumptionKg, 20);
      expect(r.data!.cylinderType, '10kg');
      expect(r.data!.nextRepurchaseEstimateAt, isNotNull);
    });

    test('si nunca declaró viene todo vacío', () async {
      fakeHttp((_) => const FakeReply(200, {
            'cylinderTypeId': null,
            'cylinderType': null,
            'avgMonthlyConsumptionKg': null,
            'nextRepurchaseEstimateAt': null,
          }));
      final r = await service.fetch();
      expect(r.data!.declared, isFalse);
      expect(r.data!.nextRepurchaseEstimateAt, isNull);
    });

    test('guarda con PATCH y devuelve la estimación nueva', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            'cylinderTypeId': 't1',
            'cylinderType': '10kg',
            'avgMonthlyConsumptionKg': 20,
            'nextRepurchaseEstimateAt': '2026-11-01T12:00:00.000Z',
          }));
      final o = await service.save(const ConsumptionDeclaration(
          cylinderTypeId: 't1', quantityPerMonth: 2));
      expect(log.single.method, 'PATCH');
      expect(log.single.body, {'cylinderTypeId': 't1', 'quantityPerMonth': 2});
      expect(o.status, ConsumptionSaveStatus.saved);
      expect(o.consumption!.avgMonthlyConsumptionKg, 20);
    });

    test('fuera de rango (400) pide confirmación y no da por guardado',
        () async {
      fakeHttp((_) => const FakeReply(400, _outOfRange));
      final o = await service.save(const ConsumptionDeclaration(
          cylinderTypeId: 't1', quantityPerMonth: 90));
      expect(o.status, ConsumptionSaveStatus.needsConfirmation);
      expect(o.consumption, isNull);
    });

    test('confirmado reenvía confirmOutOfRange: true y guarda', () async {
      final log =
          fakeHttp((r) => (r.body as Map).containsKey('confirmOutOfRange')
              ? const FakeReply(200, {
                  'cylinderTypeId': 't1',
                  'cylinderType': '10kg',
                  'avgMonthlyConsumptionKg': 900,
                  'nextRepurchaseEstimateAt': null,
                })
              : const FakeReply(400, _outOfRange));
      const d =
          ConsumptionDeclaration(cylinderTypeId: 't1', quantityPerMonth: 90);
      expect((await service.save(d)).status,
          ConsumptionSaveStatus.needsConfirmation);
      final o = await service.save(d.confirmed());
      expect(o.status, ConsumptionSaveStatus.saved);
      expect(log.last.body, containsPair('confirmOutOfRange', true));
    });

    test('otro 400 (tipo dado de baja) se muestra tal cual', () async {
      fakeHttp((_) => const FakeReply(400,
          {'message': 'El tipo de garrafa no existe o está dado de baja'}));
      final o = await service.save(const ConsumptionDeclaration(
          cylinderTypeId: 't1', quantityPerMonth: 2));
      expect(o.status, ConsumptionSaveStatus.failed);
      expect(o.message, contains('dado de baja'));
    });

    test('un 400 fuera de rango ya confirmado no vuelve a pedir confirmar',
        () async {
      fakeHttp((_) => const FakeReply(400, _outOfRange));
      final o = await service.save(const ConsumptionDeclaration(
          cylinderTypeId: 't1', quantityPerMonth: 90, confirmOutOfRange: true));
      expect(o.status, ConsumptionSaveStatus.failed);
    });

    test('sin conexión: falla con el mensaje de red', () async {
      fakeHttp((_) => const FakeReply.networkError());
      final o = await service.save(const ConsumptionDeclaration(
          cylinderTypeId: 't1', quantityPerMonth: 2));
      expect(o.status, ConsumptionSaveStatus.failed);
      expect(o.message, ApiErrorText.offline);
      expect((await service.fetch()).ok, isFalse);
    });

    test('sin sesión no llama al back', () async {
      final log = fakeHttp((_) => const FakeReply(200, {}));
      final sin = ConsumptionService(tokenReader: () async => null);
      expect((await sin.fetch()).ok, isFalse);
      expect(
          (await sin.save(const ConsumptionDeclaration(quantityPerMonth: 1)))
              .status,
          ConsumptionSaveStatus.failed);
      expect(log, isEmpty);
    });

    test('parseQuantityPerMonth acepta coma y valida el rango', () {
      expect(parseQuantityPerMonth('2'), 2);
      expect(parseQuantityPerMonth(' 1,5 '), 1.5);
      expect(parseQuantityPerMonth('0'), isNull);
      expect(parseQuantityPerMonth('1000.01'), isNull);
      expect(parseQuantityPerMonth('1.234'), isNull);
      expect(parseQuantityPerMonth('abc'), isNull);
      expect(parseQuantityPerMonth('-1'), isNull);
    });
  });

  group('registro con consumo -', () {
    late CustomerService customers;
    setUp(() => customers = CustomerService());

    test('manda consumption en POST /auth/registro', () async {
      final log = fakeHttp((_) => const FakeReply(201, {
            'user_id': 'u1',
            'full_name': 'Ana',
            'email': 'a@a.com',
            'phone_number': '+5493815550003',
            'blocked': false,
          }));
      await customers.registerCustomer(
        name: 'Ana',
        email: 'a@a.com',
        password: 'Test1234',
        phoneNumber: '+5493815550003',
        consumption: const ConsumptionDeclaration(
            cylinderTypeId: 't1', quantityPerMonth: 2),
      );
      expect(log.single.path, 'auth/registro');
      expect((log.single.body as Map)['consumption'],
          {'cylinderTypeId': 't1', 'quantityPerMonth': 2});
    });

    test('sin consumo el cuerpo no lo lleva', () async {
      final log = fakeHttp((_) => const FakeReply(500));
      await customers.registerCustomer(
          name: 'Ana',
          email: 'a@a.com',
          password: 'Test1234',
          phoneNumber: '+5493815550003');
      expect((log.single.body as Map).containsKey('consumption'), isFalse);
    });

    test('el 400 fuera de rango se distingue de un fallo cualquiera', () async {
      fakeHttp((_) => const FakeReply(400, _outOfRange));
      final r = await customers.registerCustomer(
        name: 'Ana',
        email: 'a@a.com',
        password: 'Test1234',
        phoneNumber: '+5493815550003',
        consumption: const ConsumptionDeclaration(
            cylinderTypeId: 't1', quantityPerMonth: 90),
      );
      expect(r, RegisterOutcome.consumptionOutOfRange);

      fakeHttp((_) => const FakeReply(400, {'message': 'otra cosa'}));
      expect(
          await customers.registerCustomer(
              name: 'Ana',
              email: 'a@a.com',
              password: 'Test1234',
              phoneNumber: '+5493815550003'),
          RegisterOutcome.failed);
    });
  });
}
