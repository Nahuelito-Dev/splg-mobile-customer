import 'dart:async';

import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/photo_service.dart';

/// Foto de perfil del cliente en memoria, compartida por el perfil y el menú.
/// Guarda la URL firmada sólo mientras no venció y la renueva sola un poco
/// antes del vencimiento. Una respuesta que llega después de [clear] (cierre de
/// sesión) se descarta: no puede mostrar la foto de la cuenta anterior.
class ProfilePhotoService with ListenableServiceMixin {
  ProfilePhotoService({PhotoService? photos, DateTime Function()? now})
      : _photosOverride = photos,
        _now = now ?? DateTime.now {
    listenToReactiveValues([_link]);
  }

  /// Cuánto antes del vencimiento se pide la URL de nuevo.
  static const renewLead = Duration(seconds: 30);
  static const _retryAfter = Duration(seconds: 30);
  static const _minDelay = Duration(seconds: 5);

  final PhotoService? _photosOverride;
  final DateTime Function() _now;
  PhotoService get _photos => _photosOverride ?? locator<PhotoService>();

  final ReactiveValue<SignedUrl?> _link = ReactiveValue<SignedUrl?>(null);
  bool _loaded = false;
  int _session = 0;
  Timer? _timer;

  /// El cliente tiene foto (aunque la URL esté por renovarse).
  bool get hasPhoto => _link.value != null;

  /// URL a mostrar ahora, o null si no hay foto o venció.
  String? get url {
    final link = _link.value;
    return link != null && link.isValidAt(_now()) ? link.url : null;
  }

  /// Vuelve a pedir la URL si falta, venció o se fuerza.
  Future<void> refresh({bool force = false}) async {
    final link = _link.value;
    if (!force && _loaded && (link == null || link.isValidAt(_now()))) return;
    final session = _session;
    final r = await _photos.myPhotoLink();
    if (session != _session) return;
    if (!r.ok) {
      if (_link.value != null) _schedule(_retryAfter);
      notifyListeners();
      return;
    }
    _loaded = true;
    _link.value = r.data;
    _scheduleRenewal();
  }

  Future<ApiResult<void>> upload(PickedPhoto photo) async {
    final session = _session;
    final r = await _photos.uploadMyPhoto(photo);
    if (r.ok && session == _session) await refresh(force: true);
    return r;
  }

  Future<ApiResult<void>> remove() async {
    final session = _session;
    final r = await _photos.removeMyPhoto();
    if (r.ok && session == _session) {
      _loaded = true;
      _link.value = null;
      _timer?.cancel();
    }
    return r;
  }

  /// Al cerrar sesión: no queda nada de la cuenta anterior y las respuestas
  /// en vuelo se descartan.
  void clear() {
    _session++;
    _timer?.cancel();
    _loaded = false;
    _link.value = null;
  }

  void _scheduleRenewal() {
    final link = _link.value;
    if (link == null) {
      _timer?.cancel();
      return;
    }
    var wait = link.expiresAt.difference(_now()) - renewLead;
    if (wait < _minDelay) wait = _minDelay;
    _schedule(wait);
  }

  void _schedule(Duration wait) {
    _timer?.cancel();
    _timer = Timer(wait, () => refresh(force: true));
  }
}
