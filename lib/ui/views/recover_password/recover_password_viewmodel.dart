import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';

class RecoverPasswordViewModel extends BaseViewModel {
  RecoverPasswordViewModel({String? initialEmail}) : email = initialEmail ?? '';

  final _customer = locator<CustomerService>();

  late final TextEditingController controller =
      TextEditingController(text: email);

  String email;

  /// Error para mostrar bajo el campo (null = sin error).
  String? errorMessage;

  /// true cuando el mail de recuperación ya se pidió.
  bool sent = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get emailIsValid => _emailRegExp.hasMatch(email.trim());

  void onEmailChanged(String value) {
    email = value;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> submit() async {
    if (isBusy) return;
    if (!emailIsValid) {
      errorMessage = 'Ingresá un email válido.';
      notifyListeners();
      return;
    }
    errorMessage = null;
    setBusy(true);
    final ok = await _customer.sendPasswordResetEmail(email.trim());
    setBusy(false);
    if (ok) {
      sent = true;
    } else {
      errorMessage =
          'No pudimos enviar el correo. Probá de nuevo en unos minutos.';
    }
    notifyListeners();
  }
}
