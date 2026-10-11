import 'dart:async';

import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:email_validator/email_validator.dart';

import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/login/login_view.form.dart';

class LoginViewModel extends FormViewModel {
  final _dialogService = locator<DialogService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _notificationService = locator<NotificationService>();

  String? _emailError;
  String? get emaileError => _emailError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  Future<void> onLogin() async {
    setBusy(true);
    if (!_passValidations()) {
      setBusy(false);
      return;
    }
    final success = await _customerService.signInWithEmailAndPassword(
        emailValue!, passwordValue!);
    if (success) {
      // Recién ahora hay sesión: registramos el token FCM contra el backend
      // (antes del login, initialize() en startup no tenía con qué autenticar).
      unawaited(_notificationService.requestPermissionAndRegister());
      _navigationService.back();
    } else {
      _dialogService.showDialog(
        title: 'Error',
        description:
            'No se pudo iniciar sesión. Por favor, verifique sus credenciales e intente nuevamente.',
      );
    }

    setBusy(false);
  }

  Future<void> onForgotPassword() async {
    final email = (emailValue ?? '').trim();
    if (!EmailValidator.validate(email)) {
      _emailError = 'Ingresá tu email para recuperar la contraseña';
      rebuildUi();
      return;
    }
    _emailError = null;
    setBusy(true);
    final sent = await _customerService.sendPasswordResetEmail(email);
    setBusy(false);
    await _dialogService.showDialog(
      title: sent ? 'Revisá tu correo' : 'No se pudo enviar',
      description: sent
          ? 'Si $email tiene una cuenta, te mandamos un enlace para elegir una nueva contraseña.'
          : 'No pudimos enviar el correo de recuperación. Probá de nuevo en unos minutos.',
    );
  }

  bool _passValidations() {
    if (!hasEmail) {
      _emailError = "Email inválido";
    } else {
      EmailValidator.validate(emailValue ?? '')
          ? _emailError = null
          : _emailError = "Email inválido";
    }

    if (!hasPassword) {
      _passwordError = "Contraseña inválida";
    } else {
      _passwordError = null;
    }

    if (_emailError != null || _passwordError != null) {
      return false;
    }

    return true;
  }

  void navigateToSignup() {
    _navigationService.navigateToSignupView();
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    rebuildUi();
  }
}
