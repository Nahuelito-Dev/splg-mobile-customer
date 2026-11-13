import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

import '../helpers/fake_http.dart';
import '../helpers/m3_m5_fixtures.dart';

const _base = 'http://localhost:3000/api/v2/customers/me/repurchase';

void main() {
  late RepurchaseService service;
  var keyCount = 0;

  setUp(() {
    keyCount = 0;
    service = RepurchaseService(
      tokenReader: () async => 'tok',
      keys: IdempotencyKeys(newKey: () => 'key-${++keyCount}'),
    );
  });

  group('RepurchaseServiceTest -', () {
    test('lee mi fecha estimada en la v2, con distribuidora y token', () async {
      final log = fakeHttp((_) => const FakeReply(200, {
            'estimatedAt': '2026-11-10T12:00:00.000Z',
            'daysLeft': 10,
            'source': 'history',
            'reason': null,
            'notice': {'enabled': true, 'days': 4, 'effectiveDays': 4},
            'openInvitation': null,
          }));
      final r = await service.forecast();
      expect(log.single.method, 'GET');
      expect(log.single.path, _base);
      expect(log.single.headers['X-Distributor'], 'demo');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      expect(r.ok, isTrue);
      expect(r.data!.daysLeft, 10);
      expect(r.data!.notice.days, 4);
    });

    test('sin sesión no llama al back', () async {
      final log = fakeHttp((_) => const FakeReply(200, {}));
      final r = await RepurchaseService(tokenReader: () async => null)
          .forecast();
      expect(log, isEmpty);
      expect(r.ok, isFalse);
      expect(r.message, ApiErrorText.sessionExpired);
    });

    test('lista las invitaciones abiertas', () async {
      final log = fakeHttp((_) => FakeReply(200, [invitationJson()]));
      final r = await service.openInvitations();
      expect(log.single.path, '$_base/invitations');
      expect(r.data!.single.invitationId, 'inv-1');
    });

    test('sin invitaciones (módulo apagado) devuelve la lista vacía', () async {
      fakeHttp((_) => const FakeReply(200, []));
      final r = await service.openInvitations();
      expect(r.ok, isTrue);
      expect(r.data, isEmpty);
    });

    test('guarda días con PATCH; null vuelve al de la distribuidora', () async {
      final log = fakeHttp((_) => const FakeReply(
          200, {'enabled': true, 'days': 7, 'effectiveDays': 7}));
      await service.saveNotice(days: 7);
      expect(log.last.method, 'PATCH');
      expect(log.last.path, '$_base/notice');
      expect(log.last.body, {'days': 7});

      await service.saveNotice(useDistributorDays: true);
      expect(log.last.body, {'days': null});

      await service.saveNotice(enabled: false);
      expect(log.last.body, {'enabled': false});
    });

    test('un 400 del back (días fuera de rango) llega como mensaje', () async {
      fakeHttp((_) => const FakeReply(400, {
            'message': ['days must not be greater than 30'],
            'statusCode': 400,
          }));
      final r = await service.saveNotice(days: 31);
      expect(r.ok, isFalse);
      expect(r.status, 400);
      expect(r.message, isNotEmpty);
    });

    test('aceptar crea el pedido y manda Idempotency-Key', () async {
      final log = fakeHttp((_) => FakeReply(201, {
            'invitation': invitationJson(status: 'accepted'),
            'order': {'orderId': 'o9'},
          }));
      final r = await service.accept('inv-1');
      expect(log.single.method, 'POST');
      expect(log.single.path, '$_base/invitations/inv-1/accept');
      expect(log.single.headers['Idempotency-Key'], 'key-1');
      expect(r.data!.orderId, 'o9');
    });

    test('sin respuesta, el reintento reusa la clave y no duplica el pedido',
        () async {
      var n = 0;
      final log = fakeHttp((_) => n++ == 0
          ? const FakeReply.networkError()
          : FakeReply(201, {
              'invitation': invitationJson(status: 'accepted'),
              'order': {'orderId': 'o9'},
            }));
      final first = await service.accept('inv-1');
      expect(first.ok, isFalse);
      final second = await service.accept('inv-1');
      expect(second.ok, isTrue);
      expect(log.map((r) => r.headers['Idempotency-Key']), ['key-1', 'key-1']);
    });

    test('un 409 (ya aceptada, venció) se muestra y la clave se descarta',
        () async {
      final log = fakeHttp((_) => const FakeReply(409, {
            'message': 'La invitación venció',
            'statusCode': 409,
          }));
      final r = await service.accept('inv-1');
      expect(r.ok, isFalse);
      expect(r.status, 409);
      expect(r.message, 'La invitación venció');
      await service.accept('inv-1');
      expect(log.map((x) => x.headers['Idempotency-Key']), ['key-1', 'key-2']);
    });

    test('sin dirección el cuerpo va vacío; con dirección manda addressId',
        () async {
      final log = fakeHttp((_) => FakeReply(201, {
            'invitation': invitationJson(status: 'accepted'),
            'order': {'orderId': 'o9'},
          }));
      await service.accept('inv-1');
      expect(log.last.body, isEmpty);
      await service.accept('inv-1', addressId: 'a2');
      expect(log.last.body, {'addressId': 'a2'});
    });

    test('otra dirección es otra intención: no reusa la clave pendiente',
        () async {
      final log = fakeHttp((_) => const FakeReply.networkError());
      await service.accept('inv-1', addressId: 'a2');
      await service.accept('inv-1', addressId: 'a2');
      await service.accept('inv-1', addressId: 'a3');
      expect(log.map((r) => r.headers['Idempotency-Key']),
          ['key-1', 'key-1', 'key-2']);
    });

    test('un 404 de dirección trae el motivo del back en castellano', () async {
      fakeHttp((_) => const FakeReply(404, {
            'message': 'No encontramos esa dirección entre las tuyas',
            'statusCode': 404,
          }));
      final r = await service.accept('inv-1', addressId: 'a9');
      expect(r.ok, isFalse);
      expect(r.status, 404);
      expect(r.message, 'No encontramos esa dirección entre las tuyas');
    });

    test('fuera de cobertura (400) llega con el mensaje del back', () async {
      fakeHttp((_) => const FakeReply(400, {
            'message':
                'La dirección está fuera de la zona de cobertura de la distribuidora',
            'statusCode': 400,
          }));
      final r = await service.accept('inv-1', addressId: 'a2');
      expect(r.status, 400);
      expect(r.message,
          'La dirección está fuera de la zona de cobertura de la distribuidora');
    });

    test('cotizar con otra dirección usa POST /orders/quote en la '
        'distribuidora de la invitación', () async {
      final log = fakeHttp((_) => const FakeReply(201, {
            'total': 29500,
            'subtotal': 28000,
            'zoneSurcharge': 1500,
          }));
      final r = await service.quote(invitation(), 'a2');
      expect(log.single.method, 'POST');
      expect(log.single.path, endsWith('orders/quote'));
      expect(log.single.headers['X-Distributor'], 'd1');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      expect(log.single.body, {
        'addressId': 'a2',
        'paymentMethod': 'cash',
        'items': [
          {'gasCylinderId': 'g1', 'quantity': 2, 'unitPrice': 0},
          {'gasCylinderId': 'g2', 'quantity': 1, 'unitPrice': 0},
        ],
      });
      expect(r.ok, isTrue);
      expect(r.data!.total, 29500);
    });

    test('cotizar fuera de cobertura (400) o con una dirección ajena (404) '
        'trae el texto del back', () async {
      fakeHttp((_) => const FakeReply(400, {
            'message':
                'La dirección está fuera de la zona de cobertura de la distribuidora',
            'statusCode': 400,
          }));
      final out = await service.quote(invitation(), 'a2');
      expect(out.ok, isFalse);
      expect(out.message,
          'La dirección está fuera de la zona de cobertura de la distribuidora');

      fakeHttp((_) => const FakeReply(404, {
            'message': 'No encontramos esa dirección entre las tuyas',
            'statusCode': 404,
          }));
      final gone = await service.quote(invitation(), 'a9');
      expect(gone.status, 404);
      expect(gone.message, 'No encontramos esa dirección entre las tuyas');
    });

    test('descartar hace POST a dismiss', () async {
      final log = fakeHttp((_) => FakeReply(200, invitationJson()));
      final r = await service.dismiss('inv-1');
      expect(log.single.method, 'POST');
      expect(log.single.path, '$_base/invitations/inv-1/dismiss');
      expect(r.ok, isTrue);
    });
  });
}
