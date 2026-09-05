import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('GasCylinderServiceTest -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());
  });
}
