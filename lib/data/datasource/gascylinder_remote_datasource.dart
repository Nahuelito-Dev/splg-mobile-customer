import 'package:splg_customer/core/network/api_client.dart';

class GasCylinderRemoteDatasource {
  final _apiClient = ApiClient();

  /// Cuerpo de `GET /gascylinder`. Ante cualquier falla lanza: un back caído no
  /// es "no hay garrafas".
  Future<dynamic> getGasCylinders() async {
    final response = await _apiClient.get('gascylinder');
    if (response.statusCode != 200 || response.data == null) {
      throw const FormatException('Catálogo ilegible');
    }
    return response.data;
  }
}
