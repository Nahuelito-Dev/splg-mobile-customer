import 'dart:developer';

import 'package:jennigas_customer/core/config/app_config.dart';
import 'package:jennigas_customer/core/network/api_client.dart';

class TimeSlotRemoteDatasource {
  final _apiClient = ApiClient();

  /// Trae la disponibilidad de franjas de la distribuidora para una fecha
  /// (`YYYY-MM-DD`). Endpoint público; la distribuidora va por query param.
  /// Devuelve la lista cruda de franjas (cada una con `remaining`).
  Future<List<Map<String, dynamic>>> fetchAvailability(String date) async {
    try {
      final response = await _apiClient.get(
        'time-slot/availability?date=$date&distributor=${AppConfig.distributorSlug}',
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      log('e in fetchAvailability: ${e.toString()}');
    }
    return const [];
  }
}
