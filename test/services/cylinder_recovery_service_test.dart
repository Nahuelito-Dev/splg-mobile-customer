import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';

import '../helpers/fake_http.dart';
import '../helpers/m3_m5_fixtures.dart';

const _base = 'http://localhost:3000/api/v2/cylinder-recovery/mine';

void main() {
  late CylinderRecoveryService service;

  setUp(() => service = CylinderRecoveryService(tokenReader: () async => 'tok'));

  group('CylinderRecoveryServiceTest -', () {
    test('lee mis casos con la oferta de retiro', () async {
      final log = fakeHttp((_) => FakeReply(
          200, [recoveryCaseJson(pickup: pickupJson(status: 'accepted'))]));
      final r = await service.mine();
      expect(log.single.method, 'GET');
      expect(log.single.path, _base);
      expect(log.single.headers['X-Distributor'], 'demo');
      expect(r.data!.single.serial, 'SPLG-00197');
      expect(r.data!.single.pickup!.accepted, isTrue);
    });

    test('con el módulo apagado la lista viene vacía', () async {
      fakeHttp((_) => const FakeReply(200, []));
      final r = await service.mine();
      expect(r.ok, isTrue);
      expect(r.data, isEmpty);
    });

    test('una respuesta que no es lista es un error', () async {
      fakeHttp((_) => const FakeReply(200, {'x': 1}));
      expect((await service.mine()).ok, isFalse);
    });

    test('aceptar y rechazar el retiro van a su ruta', () async {
      final log = fakeHttp((_) => FakeReply(200, recoveryCaseJson()));
      expect((await service.acceptPickup('c1')).ok, isTrue);
      expect((await service.declinePickup('c1')).ok, isTrue);
      expect(log.map((r) => '${r.method} ${r.path}'), [
        'POST $_base/c1/pickup/accept',
        'POST $_base/c1/pickup/decline',
      ]);
    });

    test('un 409 (la oferta venció) llega como mensaje', () async {
      fakeHttp((_) => const FakeReply(
          409, {'message': 'La oferta de retiro venció', 'statusCode': 409}));
      final r = await service.acceptPickup('c1');
      expect(r.ok, isFalse);
      expect(r.status, 409);
      expect(r.message, 'La oferta de retiro venció');
    });
  });
}
