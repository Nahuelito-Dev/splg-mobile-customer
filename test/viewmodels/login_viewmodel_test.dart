import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/login/login_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('LoginViewModel Tests -', () {
    late MockCustomerService customerService;
    late MockNavigationService nav;

    setUp(() {
      registerServices();
      customerService = locator<CustomerService>() as MockCustomerService;
      nav = locator<NavigationService>() as MockNavigationService;
    });
    tearDown(() => locator.reset());

    LoginViewModel withCredentials(String email, String password) =>
        LoginViewModel()
          ..formValueMap['email'] = email
          ..formValueMap['password'] = password;

    group('onLogin -', () {
      test('con sesión iniciada pide el permiso de notificaciones y va al home',
          () async {
        final notifications =
            locator<NotificationService>() as MockNotificationService;
        when(customerService.signIn(any, any))
            .thenAnswer((_) async => SignInOutcome.ok);

        await withCredentials('a@b.com', 'Test1234').onLogin();

        verify(notifications.requestPermissionAndRegister()).called(1);
        verify(nav.clearStackAndShow(Routes.homeView)).called(1);
      });

      test('con credenciales mal no pide permisos, no navega y avisa',
          () async {
        final notifications =
            locator<NotificationService>() as MockNotificationService;
        when(customerService.signIn(any, any))
            .thenAnswer((_) async => SignInOutcome.badCredentials);
        final model = withCredentials('a@b.com', 'mala');

        await model.onLogin();

        verifyNever(notifications.requestPermissionAndRegister());
        verifyNever(nav.clearStackAndShow(any));
        expect(model.errorMessage, contains('No pudimos iniciar sesión'));
        expect(model.isBusy, isFalse);
      });

      test('cuenta deshabilitada: mensaje específico', () async {
        when(customerService.signIn(any, any))
            .thenAnswer((_) async => SignInOutcome.disabled);
        final model = withCredentials('a@b.com', 'Test1234');
        await model.onLogin();
        expect(model.errorMessage,
            'Tu cuenta está deshabilitada. Contactá a tu distribuidora.');
        verifyNever(nav.clearStackAndShow(any));
      });

      test('campos vacíos: error y no llama al servicio', () async {
        final model = withCredentials('', '');
        await model.onLogin();
        verifyNever(customerService.signIn(any, any));
        expect(model.errorMessage, 'Ingresá tu email y contraseña.');
      });

      test('email mal formado: error y no llama al servicio', () async {
        final model = withCredentials('no-es-mail', 'x');
        await model.onLogin();
        verifyNever(customerService.signIn(any, any));
        expect(model.errorMessage, 'Ingresá un email válido.');
      });
    });

    test('"¿Olvidaste tu contraseña?" abre recuperar con el email escrito',
        () async {
      await withCredentials(' a@b.com ', '').onForgotPassword();
      verify(nav.navigateToRecoverPasswordView(email: 'a@b.com')).called(1);
    });

    test('sin email escrito abre recuperar sin precargar', () async {
      await withCredentials('', '').onForgotPassword();
      verify(nav.navigateToRecoverPasswordView(email: null)).called(1);
    });

    test('"Registrate" abre el alta', () async {
      await LoginViewModel().onSignup();
      verify(nav.navigateToSignupView()).called(1);
    });
  });
}
