import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';
import 'package:splg_customer/data/repository/gascylinder_repository_imp.dart';

import '../helpers/fake_http.dart';

/// Un catálogo de [total] garrafas servido de a páginas como el back.
FakeReply Function(RecordedRequest) catalogo(int total) => (r) {
      final limit = int.parse(
          '${r.query['limit'] ?? r.options.uri.queryParameters['limit'] ?? 10}');
      final offset = int.parse(
          '${r.query['offset'] ?? r.options.uri.queryParameters['offset'] ?? 0}');
      final hasta = (offset + limit).clamp(0, total);
      return FakeReply(200, {
        'gasCylinders': [
          for (var i = offset; i < hasta; i++) {'gas_cylinder_id': 'g$i'},
        ],
        'total': total,
        'limit': limit,
        'offset': offset,
      });
    };

void main() {
  test('trae todo el catálogo aunque el back lo parta en páginas', () async {
    final log = fakeHttp(catalogo(130));

    final data = await GasCylinderRemoteDatasource().getGasCylinders();

    expect((data['gasCylinders'] as List), hasLength(130));
    expect(log, hasLength(2));
    expect(log.first.options.uri.queryParameters['limit'], '100');
    expect(log.last.options.uri.queryParameters['offset'], '100');
  });

  test('un catálogo corto se pide en una sola vuelta', () async {
    final log = fakeHttp(catalogo(12));

    final data = await GasCylinderRemoteDatasource().getGasCylinders();

    expect((data['gasCylinders'] as List), hasLength(12));
    expect(log, hasLength(1));
  });

  test('si una página falla, lanza (no devuelve un catálogo a medias)',
      () async {
    var n = 0;
    fakeHttp(
        (r) => ++n == 1 ? catalogo(130)(r) : const FakeReply.networkError());

    expect(GasCylinderRemoteDatasource().getGasCylinders(), throwsA(anything));
  });

  group('catálogo público', () {
    Map<String, dynamic> producto(String id, {bool inStock = true}) => {
          'id': id,
          'type': 'Garrafa 10kg',
          'weight': 10,
          'price': 14900,
          'description': null,
          'photoUrl': null,
          'promotions': [
            {'quantity': 2, 'discountPercentage': 5},
          ],
          'inStock': inStock,
        };

    test('pide /api/v2/public/distributors/:slug/catalog sin token', () async {
      final log = fakeHttp((_) => FakeReply(200, {
            'slug': 'demo',
            'name': 'Demo',
            'products': [producto('g1')],
          }));

      await GasCylinderRemoteDatasource().getPublicCatalog();

      expect(log.single.method, 'GET');
      expect(log.single.options.uri.path,
          '/api/v2/public/distributors/demo/catalog');
      expect(log.single.headers.containsKey('Authorization'), isFalse);
    });

    test('un cuerpo ilegible o un error lanza', () async {
      fakeHttp((_) => const FakeReply(200, {'slug': 'demo'}));
      expect(
          GasCylinderRemoteDatasource().getPublicCatalog(), throwsA(anything));
      fakeHttp((_) => const FakeReply(404, {'message': 'no'}));
      expect(
          GasCylinderRemoteDatasource().getPublicCatalog(), throwsA(anything));
    });

    test('el repositorio lo pasa a garrafas con sus promociones y agotados',
        () async {
      fakeHttp((_) => FakeReply(200, {
            'slug': 'demo',
            'name': 'Demo',
            'products': [producto('g1'), producto('g2', inStock: false)],
          }));
      final repo = GasCylinderRepositoryImp(GasCylinderRemoteDatasource());

      final list = await repo.getPublicCatalog();

      expect(list.map((g) => g.id), ['g1', 'g2']);
      expect(list.first.price, 14900);
      expect(list.first.weight, '10');
      expect(list.first.active, isTrue);
      expect(list.first.discounts!.single.quantity, 2);
      expect(list.first.discounts!.single.percentage, 5);
      expect(repo.outOfStock, {'g2'});
    });
  });
}
