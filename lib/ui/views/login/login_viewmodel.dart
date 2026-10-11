import 'dart:async';

import 'package:email_validator/email_validator.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/login/login_view.form.dart';

class LoginViewModel extends FormViewModel {
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _notificationService = locator<NotificationService>();

  /// Mensaje de error para mostrar bajo el formulario (null = sin error).
  String? errorMessage;

  bool showPassword = false;

  void togglePasswordVisibility() {
    showPassword = !showPassword;
    notifyListeners();
  }

  /// Abre la recuperación con el email que ya escribió.
  Future<void> onForgotPassword() async {
    if (isBusy) return;
    final email = emailValue?.trim();
    await _navigationService.navigateToRecoverPasswordView(
      email: (email == null || email.isEmpty) ? null : email,
    );
  }

  Future<void> onSignup() => _navigationService.navigateToSignupView();

  /// Vuelve a la bienvenida. Se navega explícito porque al login también se
  /// llega con el stack limpio (sesión vencida, cierre de sesión).
  Future<void> onBack() async {
    if (isBusy) return;
    await _navigationService.clearStackAndShow(Routes.welcomeView);
  }

  Future<void> onLogin() async {
    if (isBusy) return;
    errorMessage = null;

    final email = emailValue?.trim() ?? '';
    final password = passwordValue ?? '';
    if (email.isEmpty || password.isEmpty) {
      errorMessage = 'Ingresá tu email y contraseña.';
      notifyListeners();
      return;
    }
    if (!EmailValidator.validate(email)) {
      errorMessage = 'Ingresá un email válido.';
      notifyListeners();
      return;
    }

    setBusy(true);
    final outcome = await _customerService.signIn(email, password);
    setBusy(false);

    if (outcome == SignInOutcome.ok) {
      // Recién ahora hay sesión: registramos el token FCM contra el backend.
      unawaited(_notificationService.requestPermissionAndRegister());
      await _navigationService.clearStackAndShow(Routes.homeView);
    } else {
      errorMessage = outcome == SignInOutcome.disabled
          ? 'Tu cuenta está deshabilitada. Contactá a tu distribuidora.'
          : 'No pudimos iniciar sesión. Revisá tus datos.';
      notifyListeners();
    }
  }
}
