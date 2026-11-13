import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/services/gas_cylinder_service.dart';

/// Fotos del catálogo para una pantalla: la URL firmada vigente de cada
/// garrafa y la renovación cuando vence o falla la descarga. El servicio
/// limita los pedidos al back; acá hay una sola renovación a la vez y un solo
/// repintado por renovación, nunca después de cerrar la pantalla.
mixin CatalogPhotos on BaseViewModel {
  GasCylinderService get catalogPhotoService;

  Future<void>? _photoRenewal;
  bool _renewScheduled = false;

  /// Reintento de una renovación que falló o que frenó la espera mínima del
  /// servicio: sin él, la foto queda con el asset hasta que otra cosa repinte.
  Timer? _photoRetry;
  int _photoRetries = 0;

  /// Reintentos seguidos sin fotos nuevas antes de dejar el asset.
  static const maxPhotoRetries = 5;

  /// URL vigente de la foto; null = usar el asset. Se llama desde el build:
  /// si la foto venció, la renovación se programa para después del cuadro.
  String? cylinderPhoto(String id) {
    final url = catalogPhotoService.photoUrl(id);
    if (url != null) {
      // Hay foto vigente (la renovó esta pantalla u otra): se vuelve a contar.
      _photoRetries = 0;
    } else if (catalogPhotoService.hasPhoto(id)) {
      _scheduleRenew();
    }
    return url;
  }

  /// No se pudo descargar la foto de [url] (venció o el back la rechazó).
  /// Llega fuera del build (ver `SignedImage.onError`).
  void photoFailed(String url) => _renew(failedUrl: url);

  void _scheduleRenew() {
    if (_renewScheduled || _photoRenewal != null || disposed) return;
    _renewScheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _renewScheduled = false;
      _renew();
    });
    binding.scheduleFrame();
  }

  void _renew({String? failedUrl}) {
    // La que está en curso trae las fotos nuevas para todas las que fallaron.
    if (_photoRenewal != null || disposed) return;
    _photoRenewal = _runRenewal(failedUrl);
  }

  Future<void> _runRenewal(String? failedUrl) async {
    try {
      final renewed =
          await catalogPhotoService.renewPhotos(failedUrl: failedUrl);
      if (disposed) return;
      if (renewed) {
        _photoRetries = 0;
        notifyListeners();
      } else if (failedUrl != null || catalogPhotoService.hasExpiredPhotos) {
        _schedulePhotoRetry(failedUrl);
      }
    } finally {
      _photoRenewal = null;
    }
  }

  void _schedulePhotoRetry(String? failedUrl) {
    if (_photoRetry != null || _photoRetries >= maxPhotoRetries) return;
    _photoRetries++;
    _photoRetry = Timer(GasCylinderService.photoRenewalCooldown, () {
      _photoRetry = null;
      _renew(failedUrl: failedUrl);
    });
  }

  @override
  void dispose() {
    _photoRetry?.cancel();
    _photoRetry = null;
    super.dispose();
  }
}
