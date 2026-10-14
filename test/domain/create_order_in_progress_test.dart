import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/repository/order_repository_imp.dart';
import 'package:splg_customer/domain/usecases/create_order_usecases.dart';
import 'package:splg_lib/network/api_error_text.dart';

import '../helpers/fake_http.dart';

class _Datasource extends OrderRemoteDatasource {
  _Datasource(this.results);

  final List<ApiResult<dynamic>> results;
  final keys = <String>[];

  @override
  Future<ApiResult<dynamic>> createOrder(
    Map<String, dynamic> orderData,
    String token,
    String idempotencyKey,
  ) async {
    keys.add(idempotencyKey);
    return results.removeAt(0);
  }
}

void main() {
  const pedido = {'addressId': 'a1', 'items': []};

  test('offline, 409 "en curso", offline: la clave no cambia', () async {
    final ds = _Datasource([
      const ApiResult.fail(ApiErrorText.offline),
      const ApiResult.fail(ApiErrorText.inProgress, status: 409),
      const ApiResult.fail(ApiErrorText.offline),
    ]);
    var n = 0;
    final useCase =
        CreateOrderUseCase(OrderRepositoryImp(ds), newKey: () => 'k${++n}');

    await useCase(pedido, 'tok');
    final enCurso = await useCase(pedido, 'tok');
    await useCase(pedido, 'tok');

    expect(enCurso.retryable, isTrue);
    expect(ds.keys, ['k1', 'k1', 'k1']);
  });

  test('un 409 de negocio (stock) sí descarta la clave', () async {
    final ds = _Datasource([
      const ApiResult.fail('Stock insuficiente para Garrafa 10kg', status: 409),
      const ApiResult.fail(ApiErrorText.offline),
    ]);
    var n = 0;
    final useCase =
        CreateOrderUseCase(OrderRepositoryImp(ds), newKey: () => 'k${++n}');

    final rechazo = await useCase(pedido, 'tok');
    await useCase(pedido, 'tok');

    expect(rechazo.retryable, isFalse);
    expect(ds.keys, ['k1', 'k2']);
  });

  test('de punta a punta: el 409 técnico del back se reintenta con su clave',
      () async {
    final claves = <Object?>[];
    var n = 0;
    fakeHttp((r) {
      claves.add(r.headers['Idempotency-Key']);
      return ++n == 1
          ? const FakeReply(409, {
              'message':
                  'Request en curso con la misma Idempotency-Key, reintentá'
            })
          : const FakeReply.networkError();
    });
    final useCase =
        CreateOrderUseCase(OrderRepositoryImp(OrderRemoteDatasource()));

    final r1 = await useCase(pedido, 'tok');
    await useCase(pedido, 'tok');

    expect(r1.retryable, isTrue);
    expect(claves.toSet(), hasLength(1));
  });

  test(
      'un 422 de clave ya usada avisa que el pedido puede existir y no '
      'manda otro', () async {
    final ds = _Datasource([
      const ApiResult.fail(kIdempotencyConflictText,
          status: 422, keepKey: true),
      const ApiResult.fail(ApiErrorText.offline),
    ]);
    var n = 0;
    final useCase =
        CreateOrderUseCase(OrderRepositoryImp(ds), newKey: () => 'k${++n}');

    final r = await useCase(pedido, 'tok');

    expect(r.success, isFalse);
    expect(r.idempotencyConflict, isTrue);
    expect(r.message, kOrderMaybeCreatedText);
    expect(ds.keys, ['k1']);
  });

  test(
      'de punta a punta: timeout, cambio una nota y reconfirmo = misma clave '
      'y, si el back dice 422, se avisa', () async {
    final claves = <Object?>[];
    var n = 0;
    fakeHttp((r) {
      claves.add(r.headers['Idempotency-Key']);
      return ++n == 1
          ? const FakeReply.networkError()
          : const FakeReply(422, {
              'message':
                  'Esa clave de idempotencia ya se usó con otros datos. Revisá.'
            });
    });
    final useCase =
        CreateOrderUseCase(OrderRepositoryImp(OrderRemoteDatasource()));

    await useCase(pedido, 'tok');
    final r2 = await useCase({...pedido, 'notes': 'tocar timbre'}, 'tok');

    expect(claves[0], claves[1]);
    expect(r2.idempotencyConflict, isTrue);
    expect(r2.message, kOrderMaybeCreatedText);
  });
}
