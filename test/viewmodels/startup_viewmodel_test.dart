import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/startup/startup_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('StartupViewModel -', () {
    late MockCustomerService customer;
    late MockNavigationService nav;

    setUp(() {
      registerServices();
      customer = locator<CustomerService>() as MockCustomerService;
      nav = locator<NavigationService>() as MockNavigationService;
    });
    tearDown(() => locator.reset());

    test('sin sesión entra a la bienvenida aunque el permiso siga pendiente',
        () async {
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
      verify(nav.replaceWithWelcomeView()).called(1);
      verifyNever(nav.replaceWithHomeView());
    });

    test('con sesión válida entra directo al inicio', () async {
      when(customer.isUserLoggedIn).thenReturn(true);
      when(customer.init()).thenAnswer((_) async => true);

      await StartupViewModel().runStartupLogic();

      verify(nav.replaceWithHomeView()).called(1);
      verifyNever(nav.replaceWithWelcomeView());
    });
  });
}
