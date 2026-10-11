import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_lib/splg_lib.dart';

void main() {
  group('CancelResult.fromResponse -', () {
    test('200 es éxito', () {
      expect(CancelResult.fromResponse(200, {}).success, isTrue);
    });

    test('un 400 de negocio en castellano muestra el mensaje del back', () {
      final r = CancelResult.fromResponse(400, {
        'message': 'El pedido ya está en camino. Contacte al soporte.',
        'error': 'Bad Request',
        'statusCode': 400,
      });
      expect(r.success, isFalse);
      expect(r.isRejected, isTrue);
      expect(r.retryable, isFalse);
      expect(r.failureDescription,
          'El pedido ya está en camino. Contacte al soporte.');
    });

    test('un 409 de negocio también', () {
      final r = CancelResult.fromResponse(
          409, {'message': 'No se puede cancelar un pedido finalizado'});
      expect(r.isRejected, isTrue);
      expect(r.failureDescription, 'No se puede cancelar un pedido finalizado');
    });

    test('mensajes crudos (inglés, UUID) no llegan al usuario', () {
      for (final message in [
        'reason must be shorter than or equal to 200 characters',
        'Order 3f2b8c1e-0a4d-4c3e-9b1a-2d5e6f708192 not found',
      ]) {
        final r = CancelResult.fromResponse(400, {'message': message});
        expect(r.isRejected, isFalse, reason: message);
        expect(r.failureDescription, ApiErrorText.generic);
        expect(r.failureDescription, isNot(contains('3f2b8c1e')));
      }
    });

    test('texto propio por código: 401, 403, 404, 429 y 5xx', () {
      expect(CancelResult.fromResponse(401, {}).failureDescription,
          ApiErrorText.sessionExpired);
      expect(
          CancelResult.fromResponse(403, {'message': 'Forbidden resource'})
              .failureDescription,
          ApiErrorText.forbidden);
      expect(CancelResult.fromResponse(404, {}).failureDescription,
          ApiErrorText.notFound);
      expect(CancelResult.fromResponse(429, {}).failureDescription,
          ApiErrorText.tooMany);
      expect(
          CancelResult.fromResponse(500, {'message': 'Internal server error'})
              .failureDescription,
          ApiErrorText.server);
    });

    test(
        'el 409 de idempotencia dice "ya se está procesando" y es reintentable',
        () {
      final r = CancelResult.fromResponse(409, {
        'message': 'Request en curso con la misma Idempotency-Key. Esperá.'
      });
      expect(r.isRejected, isFalse);
      expect(r.retryable, isTrue);
      expect(r.failureDescription, ApiErrorText.inProgress);
      expect(r.failureDescription, isNot(contains('Idempotency')));
    });

    test('reintentable sólo con red caída, 429 y 5xx', () {
      expect(CancelResult.fromResponse(null, null).retryable, isTrue);
      expect(CancelResult.fromResponse(429, {}).retryable, isTrue);
      expect(CancelResult.fromResponse(503, {}).retryable, isTrue);
      expect(CancelResult.fromResponse(403, {}).retryable, isFalse);
      expect(CancelResult.fromResponse(404, {}).retryable, isFalse);
    });

    test('sin respuesta usa el aviso genérico de reintentar', () {
      final r = CancelResult.fromResponse(null, null);
      expect(r.isRejected, isFalse);
      expect(r.failureDescription, contains('Intentá nuevamente'));
    });
  });
}
