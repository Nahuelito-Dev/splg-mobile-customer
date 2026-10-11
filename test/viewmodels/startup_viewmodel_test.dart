import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/startup/startup_viewmodel.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('StartupViewModel -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());

    test('entra al home aunque el permiso de notificaciones siga pendiente',
        () async {
      final customer = locator<CustomerService>() as MockCustomerService;
      when(customer.isUserLoggedIn).thenReturn(false);
      final notifications =
          locator<NotificationService>() as MockNotificationService;
      // El prompt de iOS queda esperando al usuario: nunca completa.
      when(notifications.initialize())
          .thenAnswer((_) => Completer<void>().future);

      await StartupViewModel().runStartupLogic().timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail('el arranque quedó esperando el permiso'),
          );

      verify(notifications.initialize()).called(1);
    });
  });
}
