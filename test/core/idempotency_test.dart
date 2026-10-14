import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/idempotency.dart';

const _enCurso = {
  'message': 'Request en curso con la misma Idempotency-Key, reintentá'
};
const _otrosDatos = {
  'message':
      'Esa clave de idempotencia ya se usó con otros datos. Revisá si la operación anterior se registró antes de reintentar.'
};

DioException _error(int? status, [Object? data]) {
  final req = RequestOptions(path: 'x');
  return DioException(
    requestOptions: req,
    type: status == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('keepIdempotencyKey', () {
    test('se conserva ante lo que pudo haber llegado', () {
      expect(keepIdempotencyKey(null, null), isTrue);
      expect(keepIdempotencyKey(500, {}), isTrue);
      expect(keepIdempotencyKey(502, {}), isTrue);
      expect(keepIdempotencyKey(503, {}), isTrue);
      expect(keepIdempotencyKey(429, {}), isTrue);
      expect(keepIdempotencyKey(409, _enCurso), isTrue);
      expect(keepIdempotencyKey(422, _otrosDatos), isTrue);
    });

    test('se descarta ante un rechazo de negocio o permisos', () {
      expect(keepIdempotencyKey(400, {'message': 'Fuera de zona'}), isFalse);
      expect(
          keepIdempotencyKey(409, {'message': 'Stock insuficiente'}), isFalse);
      expect(keepIdempotencyKey(401, {}), isFalse);
      expect(keepIdempotencyKey(403, {}), isFalse);
      expect(keepIdempotencyKey(404, {}), isFalse);
      expect(
          keepIdempotencyKey(422, {
            'message': ['reason must be shorter']
          }),
          isFalse);
    });
  });

  group('ApiResult.fromError', () {
    test('marca la clave a conservar y explica el 422 de idempotencia', () {
      final r = ApiResult.fromError(_error(422, _otrosDatos));
      expect(r.keepKey, isTrue);
      expect(r.message, kIdempotencyConflictText);

      expect(ApiResult.fromError(_error(null)).keepKey, isTrue);
      expect(ApiResult.fromError(_error(503, {})).keepKey, isTrue);
      expect(ApiResult.fromError(_error(409, _enCurso)).keepKey, isTrue);
      expect(
          ApiResult.fromError(_error(400, {'message': 'x'})).keepKey, isFalse);
    });
  });

  group('IdempotencyKeys', () {
    test(
        'una clave conservada vence: no devuelve la respuesta guardada de '
        'algo que ya se borró', () {
      var n = 0;
      var now = DateTime(2026, 10, 14, 12);
      final keys = IdempotencyKeys(newKey: () => 'k${++n}', now: () => now);

      expect(keys.keyFor('a'), 'k1');
      now = now.add(const Duration(minutes: 29));
      expect(keys.keyFor('a'), 'k1');
      now = now.add(const Duration(minutes: 2));
      expect(keys.keyFor('a'), 'k2');
    });

    test('misma intención, misma clave hasta que se resuelve', () {
      var n = 0;
      final keys = IdempotencyKeys(newKey: () => 'k${++n}');

      expect(keys.keyFor('a'), 'k1');
      keys.settle('a', keep: true);
      expect(keys.keyFor('a'), 'k1');
      expect(keys.keyFor('b'), 'k2');
      keys.settle('a', keep: false);
      expect(keys.keyFor('a'), 'k3');
    });
  });
}
