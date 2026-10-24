import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('el namespace del socket sale de la misma base que la API', () {
      expect(AppConfig.customersNamespace, '${AppConfig.apiBaseUrl}/customers');
      expect(AppConfig.customersNamespace, isNot(contains('/api')));
    });

    test('apiUrl cuelga de apiBaseUrl con /api/v1/', () {
      expect(AppConfig.apiUrl, '${AppConfig.apiBaseUrl}/api/v1/');
    });
  });
}
