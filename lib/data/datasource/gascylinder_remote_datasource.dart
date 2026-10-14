import 'package:splg_customer/core/network/api_client.dart';

class GasCylinderRemoteDatasource {
  final _apiClient = ApiClient();

  /// Garrafas por pedido: el máximo que acepta el back (el valor por defecto
  /// es 10 y dejaba afuera el resto del catálogo).
  static const pageSize = 100;

  /// Páginas como tope de seguridad ante un `total` que no cierra.
  static const _maxPages = 20;

  /// Cuerpo de `GET /gascylinder` con TODAS las páginas juntas
  /// (`{gasCylinders, total}`). Ante cualquier falla lanza: un back caído, o
  /// una página que no llegó, no es "no hay garrafas".
  Future<dynamic> getGasCylinders() async {
    final all = <dynamic>[];
    var total = 0;
    for (var page = 0; page < _maxPages; page++) {
      final response = await _apiClient
          .get('gascylinder?limit=$pageSize&offset=${all.length}');
      final body = response.data;
      if (response.statusCode != 200 || body is! Map) {
        throw const FormatException('Catálogo ilegible');
      }
      final items = body['gasCylinders'];
      if (items is! List) throw const FormatException('Catálogo ilegible');
      all.addAll(items);
      total = (body['total'] as num?)?.toInt() ?? all.length;
      if (items.isEmpty || all.length >= total) break;
    }
    return {'gasCylinders': all, 'total': total};
  }
}
