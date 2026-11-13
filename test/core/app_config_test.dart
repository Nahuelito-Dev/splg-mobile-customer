import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('el namespace del socket sale de la misma base que la API', () {
      expect(AppConfig.customersNamespace, '${AppConfig.apiBaseUrl}/customers');
      expect(AppConfig.customersNamespace, isNot(contains('/api')));
    });

    test('apiV2Url cuelga de apiBaseUrl con /api/v2/ y no toca la v1', () {
      expect(AppConfig.apiV2Url, '${AppConfig.apiBaseUrl}/api/v2/');
      expect(AppConfig.apiUrl, endsWith('/api/v1/'));
    });

    test('apiUrl cuelga de apiBaseUrl con /api/v1/', () {
      expect(AppConfig.apiUrl, '${AppConfig.apiBaseUrl}/api/v1/');
    });

    test('sin GPS el mapa arranca en Posadas, no en Buenos Aires', () {
      expect(AppConfig.mapFallbackLat, closeTo(-27.37, 0.05));
      expect(AppConfig.mapFallbackLng, closeTo(-55.90, 0.05));
    });
  });
}
