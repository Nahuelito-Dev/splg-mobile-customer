import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/domain/usecases/update_order_usecases.dart';

class _FakeRepository implements OrderRepository {
  _FakeRepository(this.results);

  final List<UpdateOrderResult> results;
  final keys = <String>[];

  @override
  Future<UpdateOrderResult> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    keys.add('$orderId:$idempotencyKey');
    return results.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late int counter;
  String newKey() => 'key-${++counter}';

  setUp(() => counter = 0);

  test(
      'los reintentos tras red caída/5xx reusan la clave aunque cambie el cuerpo',
      () async {
    final repo = _FakeRepository([
      const UpdateOrderResult(success: false, retryable: true),
      const UpdateOrderResult(success: false, retryable: true),
      const UpdateOrderResult(success: true),
    ]);
    final useCase = UpdateOrderUseCase(repo, newKey: newKey);

    await useCase('o1', {'notes': 'a'}, 'tok');
    await useCase('o1', {'notes': 'b'}, 'tok');
    final last = await useCase('o1', {'notes': 'c'}, 'tok');

    expect(last.success, isTrue);
    expect(repo.keys, ['o1:key-1', 'o1:key-1', 'o1:key-1']);
  });

  test('una edición resuelta o rechazada descarta la clave', () async {
    final repo = _FakeRepository([
      const UpdateOrderResult(success: true),
      const UpdateOrderResult(success: false, rejected: true),
      const UpdateOrderResult(success: true),
    ]);
    final useCase = UpdateOrderUseCase(repo, newKey: newKey);

    await useCase('o1', {}, 'tok');
    await useCase('o1', {}, 'tok');
    await useCase('o1', {}, 'tok');

    expect(repo.keys, ['o1:key-1', 'o1:key-2', 'o1:key-3']);
  });

  test('el 422 de la clave ya usada se explica y la próxima edición es nueva',
      () async {
    final repo = _FakeRepository([
      const UpdateOrderResult(success: false, idempotencyConflict: true),
      const UpdateOrderResult(success: true),
    ]);
    final useCase = UpdateOrderUseCase(repo, newKey: newKey);

    await useCase('o1', {}, 'tok');
    await useCase('o1', {}, 'tok');

    expect(repo.keys, ['o1:key-1', 'o1:key-2']);
  });

  test('cada pedido tiene su propia clave', () async {
    final repo = _FakeRepository([
      const UpdateOrderResult(success: false, retryable: true),
      const UpdateOrderResult(success: false, retryable: true),
    ]);
    final useCase = UpdateOrderUseCase(repo, newKey: newKey);

    await useCase('o1', {}, 'tok');
    await useCase('o2', {}, 'tok');

    expect(repo.keys, ['o1:key-1', 'o2:key-2']);
  });
}
