import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/photo_service.dart';

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

  final _photoService = locator<PhotoService>();
  PhotoPicker picker = PhotoPicker();

  /// Foto adjunta (opcional), ya reducida y sin metadatos.
  PickedPhoto? photo;

  /// El reclamo se creó pero la foto no subió: se avisa sin perder el reclamo.
  String? photoWarning;

  final TextEditingController descriptionController = TextEditingController();

  String _reason = kClaimReasons.first;
  String get reason => _reason;

  String? errorMessage;

  void setReason(String value) {
    _reason = value;
    errorMessage = null;
    notifyListeners();
  }

  /// Eligiendo o procesando la foto: no se puede enviar el reclamo hasta que
  /// termine.
  bool processingPhoto = false;

  Future<void> attach(PhotoSource source) async {
    if (isBusy || processingPhoto) return;
    processingPhoto = true;
    notifyListeners();
    try {
      final picked = await picker.pick(source);
      if (picked == null) return;
      photo = picked;
      errorMessage = null;
    } on PhotoTooLarge {
      errorMessage = PhotoTooLarge.message;
    } on PhotoUnreadable {
      errorMessage = PhotoUnreadable.message;
    } catch (_) {
      errorMessage = PhotoUnreadable.message;
    } finally {
      processingPhoto = false;
    }
    notifyListeners();
  }

  void removePhoto() {
    photo = null;
    notifyListeners();
  }

  Future<bool> submit(String orderId) async {
    if (isBusy || processingPhoto) return false;
    final description = descriptionController.text.trim();
    if (description.isEmpty) {
      errorMessage = 'Contanos qué pasó antes de enviar.';
      notifyListeners();
      return false;
    }

    setBusy(true);
    errorMessage = null;
    final result = await _claimService.createClaim(
      orderId: orderId,
      reason: _reason,
      description: description,
    );

    if (!result.ok) {
      setBusy(false);
      errorMessage = result.message;
      notifyListeners();
      return false;
    }
    // El reclamo ya existe: si la foto falla no se pierde, se avisa.
    final claimId = result.data;
    if (photo != null) {
      final up = claimId == null || claimId.isEmpty
          ? const ApiResult<void>.fail('Probá de nuevo desde Mis reclamos.')
          : await _photoService.uploadClaimPhoto(claimId, photo!);
      if (!up.ok) {
        photoWarning = 'Tu reclamo se envió, pero no pudimos subir la foto: '
            '${up.message} Podés agregarla desde Mis reclamos.';
      }
    }
    setBusy(false);
    return true;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}
