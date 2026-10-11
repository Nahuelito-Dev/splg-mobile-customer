import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:splg_customer/ui/views/login/login_viewmodel.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('LoginViewModel Tests -', () {
    late MockCustomerService customerService;
    late MockDialogService dialogService;

    setUp(() {
      registerServices();
      customerService = locator<CustomerService>() as MockCustomerService;
      dialogService = locator<DialogService>() as MockDialogService;
    });
    tearDown(() => locator.reset());

    group('onLogin -', () {
      test(
          'con sesión iniciada pide el permiso de notificaciones (no al arrancar)',
          () async {
        final notifications =
            locator<NotificationService>() as MockNotificationService;
        when(customerService.signInWithEmailAndPassword(any, any))
            .thenAnswer((_) async => true);
        final model = LoginViewModel()
          ..formValueMap['email'] = 'a@b.com'
          ..formValueMap['password'] = 'Test1234';

        await model.onLogin();

        verify(notifications.requestPermissionAndRegister()).called(1);
      });

      test('con credenciales mal no pide permisos', () async {
        final notifications =
            locator<NotificationService>() as MockNotificationService;
        when(customerService.signInWithEmailAndPassword(any, any))
            .thenAnswer((_) async => false);
        final model = LoginViewModel()
          ..formValueMap['email'] = 'a@b.com'
          ..formValueMap['password'] = 'mala';

        await model.onLogin();

        verifyNever(notifications.requestPermissionAndRegister());
      });
    });

    group('onForgotPassword -', () {
      test('con email inválido no llama al servicio y marca el error',
          () async {
        final model = LoginViewModel()..formValueMap['email'] = 'no-es-mail';

        await model.onForgotPassword();

        verifyNever(customerService.sendPasswordResetEmail(any));
        expect(model.emaileError, isNotNull);
      });

      test('con email válido pide el mail de recuperación y avisa', () async {
        when(customerService.sendPasswordResetEmail('a@b.com'))
            .thenAnswer((_) async => true);
        final model = LoginViewModel()..formValueMap['email'] = 'a@b.com';

        await model.onForgotPassword();

        verify(customerService.sendPasswordResetEmail('a@b.com')).called(1);
        verify(dialogService.showDialog(
          title: 'Revisá tu correo',
          description: anyNamed('description'),
        )).called(1);
        expect(model.isBusy, isFalse);
      });

      test('si Firebase falla muestra el error', () async {
        when(customerService.sendPasswordResetEmail(any))
            .thenAnswer((_) async => false);
        final model = LoginViewModel()..formValueMap['email'] = 'a@b.com';

        await model.onForgotPassword();

        verify(dialogService.showDialog(
          title: 'No se pudo enviar',
          description: anyNamed('description'),
        )).called(1);
      });
    });
  });
}
