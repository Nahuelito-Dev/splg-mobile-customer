import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';

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
}
