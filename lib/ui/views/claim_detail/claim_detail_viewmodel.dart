import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/photo_service.dart';

/// Foto del reclamo: se pide la URL firmada al abrir el detalle (y se renueva
/// si venció) y, mientras el reclamo está abierto, se puede agregar o cambiar.
class ClaimDetailViewModel extends BaseViewModel {
  ClaimDetailViewModel(this.claimId, this.status);

  final String claimId;
  final ClaimStatus status;
  final _photos = locator<PhotoService>();
  PhotoPicker picker = PhotoPicker();

  SignedUrl? _link;
  bool loadingPhoto = true;

  /// Mensaje del último intento de subir la foto que no salió.
  String? photoError;

  bool get hasPhoto => _link != null;

  /// El back sólo acepta la foto mientras el reclamo no está resuelto ni
  /// rechazado (409).
  bool get canAttach =>
      status == ClaimStatus.pending || status == ClaimStatus.inProcess;

  /// URL a mostrar, o null si no hay foto o venció.
  String? get photoUrl => _link?.isValid == true ? _link!.url : null;

  Future<void> loadPhoto() async {
    loadingPhoto = true;
    notifyListeners();
    final r = await _photos.claimPhotoLink(claimId);
    _link = r.ok ? r.data : null;
    loadingPhoto = false;
    notifyListeners();
  }

  /// Elegir y subir; un segundo toque mientras trabaja se ignora.
  Future<void> attach(PhotoSource source) async {
    if (busy('photo') || !canAttach) return;
    photoError = null;
    setBusyForObject('photo', true);
    try {
      final picked = await picker.pick(source);
      if (picked == null) return;
      final up = await _photos.uploadClaimPhoto(claimId, picked);
      if (!up.ok) {
        photoError = up.message;
        return;
      }
      await loadPhoto();
    } on PhotoTooLarge {
      photoError = PhotoTooLarge.message;
    } on PhotoUnreadable {
      photoError = PhotoUnreadable.message;
    } catch (_) {
      photoError = PhotoUnreadable.message;
    } finally {
      setBusyForObject('photo', false);
    }
  }
}
