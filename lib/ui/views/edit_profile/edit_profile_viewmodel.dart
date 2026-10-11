import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';

/// Editar nombre y teléfono (`PATCH /users/:id`).
class EditProfileViewModel extends BaseViewModel {
  final _customer = locator<CustomerService>();
  final _nav = locator<NavigationService>();

  late final name = TextEditingController(text: _customer.customer.fullName);
  late final phone = TextEditingController(
      text: _customer.customer.phoneNumber.replaceFirst(RegExp(r'^\+?54'), ''));

  String? nameError;
  String? phoneError;
  String? errorMessage;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (isBusy) return;
    nameError =
        name.text.trim().length >= 2 ? null : 'Ingresá tu nombre y apellido.';
    phoneError = SplgPhoneField.isValid(phone.text)
        ? null
        : 'Ingresá un teléfono válido.';
    errorMessage = null;
    if (nameError != null || phoneError != null) {
      notifyListeners();
      return;
    }
    setBusy(true);
    final result = await _customer.updateProfile(
      fullName: name.text,
      phoneNumber: SplgPhoneField.toE164(phone.text),
    );
    setBusy(false);
    if (result.ok) {
      _nav.back(result: true);
    } else {
      errorMessage = result.message;
      notifyListeners();
    }
  }
}
