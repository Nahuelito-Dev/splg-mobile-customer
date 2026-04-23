import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';

class GasCylinderRemoteDatasource {
  final _apiClient = ApiClient();

  Future<(bool, dynamic)> getGasCylinders() async {
    try {
      final response = await _apiClient.get('gascylinder');

      if (response.statusCode == 200) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in getGasCylinders: ${e.toString()}');
    }

    return (false, null);
  }
}
