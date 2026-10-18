import 'dart:async';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/splg_lib.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';

/// Alta en tres pasos: 1 "Tus datos" (nombre y teléfono), 2 "Tu cuenta"
/// (email, contraseña y aceptación de términos y privacidad) y 3 "Tu consumo"
/// (opcional: garrafa habitual y cuántas por mes).
class SignupViewModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _notificationService = locator<NotificationService>();
  final _dialogService = locator<DialogService>();
  final _gasCylinderService = locator<GasCylinderService>();

  static const stepCount = 3;

  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final repeat = TextEditingController();
  final consumptionQuantity = TextEditingController();

  int step = 0;
  bool acceptedTerms = false;
  bool acceptedPrivacy = false;

  String? nameError;
  String? phoneError;
  String? emailError;
  String? passwordError;
  String? repeatError;
  String? consumptionError;

  /// Garrafas que se ofrecen para declarar el consumo (las de la distribuidora).
  List<GasCylinder> cylinders = [];
  bool loadingCylinders = false;
  String? consumptionCylinderId;

  /// Error del servidor o de las casillas, bajo el formulario.
  String? generalError;

  @override
  void dispose() {
    for (final c in [
      name,
      phone,
      email,
      password,
      repeat,
      consumptionQuantity
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Mínimo 8 caracteres, una mayúscula y un número.
  static bool meetsPolicy(String p) =>
      p.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(p) &&
      RegExp(r'\d').hasMatch(p);

  void setTerms(bool v) {
    acceptedTerms = v;
    generalError = null;
    notifyListeners();
  }

  void setPrivacy(bool v) {
    acceptedPrivacy = v;
    generalError = null;
    notifyListeners();
  }

  bool _validateStep1() {
    nameError =
        name.text.trim().length >= 2 ? null : 'Ingresá tu nombre y apellido.';
    phoneError = SplgPhoneField.isValid(phone.text)
        ? null
        : 'Ingresá un teléfono válido.';
    notifyListeners();
    return nameError == null && phoneError == null;
  }

  bool _validateStep2() {
    final mail = email.text.trim();
    emailError = mail.isEmpty
        ? 'Ingresá tu email.'
        : (EmailValidator.validate(mail) ? null : 'Ingresá un email válido.');
    passwordError = meetsPolicy(password.text)
        ? null
        : 'Usá al menos 8 caracteres, una mayúscula y un número.';
    repeatError =
        repeat.text == password.text ? null : 'Las contraseñas no coinciden.';
    generalError = (acceptedTerms && acceptedPrivacy)
        ? null
        : 'Para registrarte aceptá los términos y la política de privacidad.';
    notifyListeners();
    return emailError == null &&
        passwordError == null &&
        repeatError == null &&
        generalError == null;
  }

  Future<void> next() async {
    if (isBusy) return;
    if (step == 0) {
      if (_validateStep1()) {
        step = 1;
        notifyListeners();
      }
      return;
    }
    if (step == 1) {
      if (_validateStep2()) {
        step = 2;
        notifyListeners();
        unawaited(_loadCylinders());
      }
      return;
    }
    if (_validateConsumption()) await _register(declaration: _declaration());
  }

  /// "Omitir": el registro sigue sin consumo declarado.
  Future<void> skipConsumption() async {
    if (isBusy) return;
    await _register();
  }

  Future<void> _loadCylinders() async {
    if (cylinders.isNotEmpty || loadingCylinders) return;
    loadingCylinders = true;
    notifyListeners();
    try {
      cylinders = await _gasCylinderService.getGasCylinders();
    } catch (_) {
      cylinders = [];
    }
    loadingCylinders = false;
    notifyListeners();
  }

  void selectConsumptionCylinder(String id) {
    consumptionCylinderId = id;
    consumptionError = null;
    notifyListeners();
  }

  /// El paso 3 es opcional: vacío no declara nada; a medias, pide completar.
  bool _validateConsumption() {
    final empty = consumptionQuantity.text.trim().isEmpty &&
        consumptionCylinderId == null;
    if (empty) {
      consumptionError = null;
      notifyListeners();
      return true;
    }
    if (consumptionCylinderId == null) {
      consumptionError = 'Elegí tu garrafa habitual.';
    } else if (parseQuantityPerMonth(consumptionQuantity.text) == null) {
      consumptionError =
          'Ingresá cuántas garrafas consumís por mes (de 0,01 a 1000).';
    } else {
      consumptionError = null;
    }
    notifyListeners();
    return consumptionError == null;
  }

  ConsumptionDeclaration? _declaration() {
    final qty = parseQuantityPerMonth(consumptionQuantity.text);
    if (qty == null || consumptionCylinderId == null) return null;
    return ConsumptionDeclaration(
        cylinderTypeId: consumptionCylinderId, quantityPerMonth: qty);
  }

  Future<void> back() async {
    if (step > 0) {
      step -= 1;
      generalError = null;
      consumptionError = null;
      notifyListeners();
    } else {
      _navigationService.back();
    }
  }

  Future<void> _register({ConsumptionDeclaration? declaration}) async {
    setBusy(true);
    generalError = null;
    consumptionError = null;
    var outcome = await _registerWith(declaration);
    if (outcome == RegisterOutcome.consumptionOutOfRange &&
        declaration != null) {
      // Nada se creó: se pide confirmar y se reenvía igual.
      final answer = await _dialogService.showConfirmationDialog(
        title: 'Consumo fuera de lo habitual',
        description: 'Lo que declaraste queda fuera del rango razonable '
            '($consumptionMinKg a $consumptionMaxKg kg por mes). '
            '¿Querés registrarte con ese consumo?',
        confirmationTitle: 'Confirmar',
        cancelTitle: 'Corregir',
      );
      if (answer?.confirmed != true) {
        setBusy(false);
        return;
      }
      outcome = await _registerWith(declaration.confirmed());
    }

    if (outcome == RegisterOutcome.created) {
      final signedIn =
          await _customerService.signIn(email.text.trim(), password.text);
      if (signedIn != SignInOutcome.ok) {
        // Sin sesión no se avanza: la cuenta existe, pero hay que ingresar.
        setBusy(false);
        await _dialogService.showDialog(
          title: 'Cuenta creada',
          description: 'Tu cuenta se creó, pero no pudimos iniciar la sesión. '
              'Ingresá con tu email y contraseña.',
          buttonTitle: 'Aceptar',
        );
        await _navigationService.clearStackAndShow(Routes.loginView);
        return;
      }
      unawaited(_notificationService.requestPermissionAndRegister());
      setBusy(false);
      await _navigationService.clearStackAndShow(Routes.signupDoneView);
      return;
    }
    generalError = outcome == RegisterOutcome.alreadyExists
        ? 'Ese correo pertenece a una cuenta dada de baja o ya registrada. '
            'Si diste de baja tu cuenta, contactá a tu distribuidora.'
        : 'No pudimos completar el registro. Probá de nuevo.';
    setBusy(false);
  }

  Future<RegisterOutcome> _registerWith(ConsumptionDeclaration? declaration) =>
      _customerService.registerCustomer(
        name: name.text.trim(),
        email: email.text.trim(),
        password: password.text,
        phoneNumber: SplgPhoneField.toE164(phone.text),
        consumption: declaration,
      );

  void openTerms() =>
      _navigationService.navigateToLegalView(document: LegalDocument.terms);

  void openPrivacy() =>
      _navigationService.navigateToLegalView(document: LegalDocument.privacy);
}
