import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:email_validator/email_validator.dart';

import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/ui/common/app_strings.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/signup/signup_view.form.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';

class SignupViewModel extends FormViewModel {
  final _dialogService = locator<DialogService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _notificationService = locator<NotificationService>();

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  String? _nameError;
  String? get nameError => _nameError;

  String? _emailError;
  String? get emailError => _emailError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  String? _phoneError;
  String? get phoneError => _phoneError;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    rebuildUi();
  }

  Future<void> onRegister() async {
    setBusy(true);
    if (!_passValidations()) {
      setBusy(false);
      return;
    }

    final formattedPhone = _formatPhoneNumber(phoneValue!);

    final isRegistered = await _customerService.registerCustomer(
      name: nameValue!,
      email: emailValue!,
      password: passwordValue!,
      phoneNumber: formattedPhone,
    );

    if (isRegistered) {
      await _customerService.signInWithEmailAndPassword(
          emailValue!, passwordValue!);
      // Recién ahora hay sesión: registramos el token FCM contra el backend.
      await _notificationService.registerCurrentToken();
      _navigationService.clearStackAndShow(Routes.homeView);
    } else {
      await _dialogService.showDialog(
        title: signupViewErrorDialogTitle,
        description: signupViewErrorDialogDescription,
      );
    }

    setBusy(false);
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-_]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+54')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('54') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }

    cleaned = cleaned.replaceAll('+', '');

    return '+54$cleaned';
  }

  bool _passValidations() {
    bool isValid = true;

    if (!hasName || nameValue!.isEmpty) {
      _nameError = signupViewNameError;
      isValid = false;
    } else {
      _nameError = null;
    }

    if (!hasEmail || emailValue!.isEmpty) {
      _emailError = signupViewEmailError;
      isValid = false;
    } else if (!EmailValidator.validate(emailValue!)) {
      _emailError = signupViewVaildEmailError;
      isValid = false;
    } else {
      _emailError = null;
    }

    if (!hasPassword || passwordValue!.isEmpty) {
      _passwordError = 'La contraseña es requerida';
      isValid = false;
    } else {
      _passwordError = null;
    }

    if (!hasPhone || phoneValue!.isEmpty) {
      _phoneError = signupViewPhoneError;
      isValid = false;
    } else {
      _phoneError = null;
    }

    return isValid;
  }

  void navigateToLogin() {
    _navigationService.back();
  }

  Future<void> navigateToTerms() async {
    await _navigationService.navigateToLegalView(
      document: LegalDocument.terms,
    );
  }

  Future<void> navigateToPrivacyPolicy() async {
    await _navigationService.navigateToLegalView(
      document: LegalDocument.privacy,
    );
  }
}
