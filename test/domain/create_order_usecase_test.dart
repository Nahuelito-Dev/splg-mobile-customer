import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/usecases/create_order_usecases.dart';

class _FakeRepository implements OrderRepository {
  _FakeRepository(this.results);

  final List<CreateOrderResult> results;
  final keys = <String>[];

  @override
  Future<CreateOrderResult> createOrder(
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    keys.add(idempotencyKey);
    return results.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _offline = CreateOrderResult(success: false);
const _rejected = CreateOrderResult(
    success: false, message: 'Fuera de zona', retryable: false);
const _created = CreateOrderResult(success: true);

void main() {
  group('CreateOrderUseCase - Idempotency-Key por intención', () {
    late int counter;
    String newKey() => 'key-${++counter}';
    const pedido = {'addressId': 'a1', 'items': []};

    setUp(() => counter = 0);

    test('el reintento tras un error de red lleva la misma clave', () async {
      final repo = _FakeRepository([_offline, _offline, _created]);
      final useCase = CreateOrderUseCase(repo, newKey: newKey);

      await useCase(pedido, 'tok');
      await useCase({...pedido}, 'tok');
      final last = await useCase(pedido, 'tok');

      expect(last.success, isTrue);
      expect(repo.keys, ['key-1', 'key-1', 'key-1']);
    });

    test('un pedido nuevo, después de crear el anterior, usa otra clave',
        () async {
      final repo = _FakeRepository([_created, _created]);
      final useCase = CreateOrderUseCase(repo, newKey: newKey);

      await useCase(pedido, 'tok');
      await useCase(pedido, 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('tras un rechazo de negocio, el nuevo intento lleva otra clave',
        () async {
      final repo = _FakeRepository([_rejected, _created]);
      final useCase = CreateOrderUseCase(repo, newKey: newKey);

      await useCase(pedido, 'tok');
      await useCase(pedido, 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('si el pedido cambió entre intentos (una nota) la clave es la misma',
        () async {
      // Un timeout no dice si el primero llegó: otra clave duplicaría el pedido.
      final repo = _FakeRepository([_offline, _created]);
      final useCase = CreateOrderUseCase(repo, newKey: newKey);

      await useCase(pedido, 'tok');
      await useCase({...pedido, 'notes': 'tocar timbre'}, 'tok');

      expect(repo.keys, ['key-1', 'key-1']);
    });

    test('la clave vence: pasado el tiempo es un pedido nuevo', () async {
      var now = DateTime(2026, 10, 14, 12);
      final repo = _FakeRepository([_offline, _offline]);
      final useCase = CreateOrderUseCase(repo, newKey: newKey, now: () => now);

      await useCase(pedido, 'tok');
      now = now.add(const Duration(hours: 1));
      await useCase(pedido, 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('clear() descarta la intención en curso', () async {
      final repo = _FakeRepository([_offline, _created]);
      final useCase = CreateOrderUseCase(repo, newKey: newKey);

      await useCase(pedido, 'tok');
      useCase.clear();
      await useCase(pedido, 'tok');

      expect(repo.keys, ['key-1', 'key-2']);
    });
  });
}
