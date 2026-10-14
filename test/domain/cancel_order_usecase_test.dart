import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/usecases/cancel_order_usecases.dart';

/// Repositorio que guarda las claves que recibe y devuelve resultados en orden.
class _FakeRepository implements OrderRepository {
  _FakeRepository(this.results);

  final List<CancelResult> results;
  final keys = <String>[];

  @override
  Future<CancelResult> cancelOrder(
    String orderId,
    String token,
    String idempotencyKey, {
    String? reason,
  }) async {
    keys.add(idempotencyKey);
    return results.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('CancelOrderUseCase - Idempotency-Key por intención', () {
    late int counter;
    String newKey() => 'key-${++counter}';

    setUp(() => counter = 0);

    test('los reintentos tras un fallo de red/5xx reusan la misma clave',
        () async {
      final repo = _FakeRepository([
        const CancelResult.failed(),
        CancelResult.fromResponse(503, {}),
        const CancelResult.ok(),
      ]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);

      await useCase('o1', 'tok');
      await useCase('o1', 'tok');
      final last = await useCase('o1', 'tok');

      expect(last.success, isTrue);
      expect(repo.keys, ['key-1', 'key-1', 'key-1']);
    });

    test('una intención nueva (después de resolverse) usa otra clave',
        () async {
      final repo = _FakeRepository([
        const CancelResult.ok(),
        const CancelResult.rejected('El pedido ya está en camino.'),
      ]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);

      await useCase('o1', 'tok');
      await useCase('o1', 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('un rechazo definitivo (403) descarta la clave', () async {
      final repo = _FakeRepository([
        CancelResult.fromResponse(403, {}),
        const CancelResult.ok(),
      ]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);

      await useCase('o1', 'tok');
      await useCase('o1', 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('cada pedido tiene su propia clave', () async {
      final repo = _FakeRepository([
        const CancelResult.failed(),
        const CancelResult.failed(),
      ]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);

      await useCase('o1', 'tok');
      await useCase('o2', 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('reintentar con el mismo motivo reusa la clave', () async {
      final repo = _FakeRepository([
        const CancelResult.failed(),
        const CancelResult.ok(),
      ]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);

      await useCase('o1', 'tok', reason: 'Me equivoqué');
      await useCase('o1', 'tok', reason: ' Me equivoqué ');

      expect(repo.keys, ['key-1', 'key-1']);
    });

    test('otro motivo tras un error de red es otra intención: otra clave',
        () async {
      final repo = _FakeRepository([
        const CancelResult.failed(),
        const CancelResult.ok(),
      ]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);

      await useCase('o1', 'tok', reason: 'Me equivoqué');
      await useCase('o1', 'tok', reason: 'Ya no lo necesito');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('el 422 por clave reutilizada se explica y conserva la clave',
        () async {
      final result = CancelResult.fromResponse(422, {
        'message':
            'Esa clave de idempotencia ya se usó con otros datos. Revisá si la operación anterior se registró antes de reintentar.',
      });

      expect(result.success, isFalse);
      expect(result.retryable, isTrue);
      expect(result.failureDescription, contains('otro motivo'));

      // La primera cancelación llegó: una clave nueva podría procesarla dos
      // veces.
      final repo = _FakeRepository([result, const CancelResult.ok()]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);
      await useCase('o1', 'tok', reason: 'a');
      await useCase('o1', 'tok', reason: 'a');
      expect(repo.keys, ['key-1', 'key-1']);
    });

    test('un 422 de validación (no de idempotencia) descarta la clave',
        () async {
      final result = CancelResult.fromResponse(422, {
        'message': ['reason must be shorter than 500 characters'],
      });
      expect(result.retryable, isFalse);

      final repo = _FakeRepository([result, const CancelResult.ok()]);
      final useCase = CancelOrderUseCase(repo, newKey: newKey);
      await useCase('o1', 'tok', reason: 'a');
      await useCase('o1', 'tok', reason: 'a');
      expect(repo.keys, ['key-1', 'key-2']);
    });
  });
}
