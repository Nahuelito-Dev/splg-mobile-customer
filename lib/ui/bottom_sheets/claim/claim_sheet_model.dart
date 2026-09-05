import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/claim_service.dart';

/// Motivos frecuentes de reclamo. Son etiquetas libres (el backend guarda
/// `reason` como string), la última abre a texto libre en la descripción.
const List<String> kClaimReasons = [
  'No llegó el pedido',
  'Garrafa en mal estado',
  'Cobro incorrecto',
  'Demora excesiva',
  'Trato del chofer',
  'Otro',
];

class ClaimSheetModel extends BaseViewModel {
  final _claimService = locator<ClaimService>();

  final TextEditingController descriptionController = TextEditingController();

  String _reason = kClaimReasons.first;
  String get reason => _reason;

  String? errorMessage;

  void setReason(String value) {
    _reason = value;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> submit(String orderId) async {
    final description = descriptionController.text.trim();
    if (description.isEmpty) {
      errorMessage = 'Contanos qué pasó antes de enviar.';
      notifyListeners();
      return false;
    }

    setBusy(true);
    errorMessage = null;
    final ok = await _claimService.createClaim(
      orderId: orderId,
      reason: _reason,
      description: description,
    );
    setBusy(false);

    if (!ok) {
      errorMessage = 'No se pudo enviar el reclamo. Intentá de nuevo.';
      notifyListeners();
    }
    return ok;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}
