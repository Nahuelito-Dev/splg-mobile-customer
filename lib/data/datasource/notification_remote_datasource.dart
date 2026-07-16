import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';

class NotificationRemoteDatasource {
  final _apiClient = ApiClient();

  /// Registra el token FCM del device (`POST /notifications/token`). El
  /// backend lo guarda contra el customer (`notification_token`) para poder
  /// mandar push en cambios de estado del pedido. Requiere sesión (el
  /// controller vive detrás del AuthGuard global).
  Future<bool> registerToken({
    required String userId,
    required String fcmToken,
    required String platform,
    required String authToken,
  }) async {
    try {
      final response = await _apiClient.post(
        'notifications/token',
        {
          'userId': userId,
          'token': fcmToken,
          'platform': platform,
        },
        authToken,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      log('e in registerToken: ${e.toString()}');
    }
    return false;
  }
}
