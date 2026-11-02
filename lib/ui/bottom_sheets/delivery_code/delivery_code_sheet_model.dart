import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';

/// Ingreso a mano del código de entrega que muestra el chofer (debajo de su QR).
/// Confirma contra el mismo servicio que el escáner
/// (`POST /orders/:id/confirm-delivery`) y muestra el rechazo del back en la
/// misma hoja.
class DeliveryCodeSheetModel extends BaseViewModel {
  DeliveryCodeSheetModel({required this.orderId});

  /// Largo que puede tener un código de entrega. El back genera 6 dígitos, pero
  /// los pedidos viejos traen 10 caracteres hexadecimales: la app no decide por
  /// el formato exacto, deja que el back responda.
  static const minLength = 4;
  static const maxLength = 12;
  static final _valid = RegExp(r'^[A-Z0-9]+$');

  /// true si [normalized] (ya pasado por [normalize]) tiene forma plausible
  /// de código: alfanumérico de [minLength] a [maxLength].
  static bool isPlausible(String normalized) =>
      _valid.hasMatch(normalized) &&
      normalized.length >= minLength &&
      normalized.length <= maxLength;

  final String orderId;
  final codeController = TextEditingController();

  String? errorMessage;

  /// true si el 401 ya lo atendió la sesión: la hoja se cierra sin más aviso.
  bool sessionExpired = false;

  /// Deja el código como lo espera el back: sin espacios y en mayúsculas.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Mensaje de validación o null si el código es presentable.
  static String? validate(String raw) {
    final code = normalize(raw);
    if (code.isEmpty) return 'Ingresá el código que te muestra el repartidor.';
    if (!isPlausible(code)) {
      return 'El código tiene entre $minLength y $maxLength letras o números. Revisalo.';
    }
    return null;
  }

  /// Valida y confirma. Devuelve true si el pedido quedó entregado.
  Future<bool> submit() async {
    if (isBusy) return false;
    final invalid = validate(codeController.text);
    if (invalid != null) {
      errorMessage = invalid;
      notifyListeners();
      return false;
    }

    setBusy(true);
    errorMessage = null;
    final token = await locator<CustomerService>().token;
    if (token == null) {
      setBusy(false);
      errorMessage = 'Tu sesión venció. Volvé a iniciar sesión.';
      notifyListeners();
      return false;
    }
    final outcome = await locator<OrderTrackingService>().confirmDelivery(
      orderId,
      normalize(codeController.text),
      token,
    );
    setBusy(false);

    if (outcome.isSuccess) return true;
    if (outcome.result == ConfirmDeliveryResult.sessionExpired) {
      sessionExpired = true;
      return false;
    }
    errorMessage =
        outcome.message ?? 'No pudimos confirmar la entrega. Probá de nuevo.';
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }
}
