import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/customer.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/profile_photo_service.dart';
import 'package:splg_customer/services/session_service.dart';

class ProfileViewModel extends ReactiveViewModel {
  final _customerService = locator<CustomerService>();
  final _nav = locator<NavigationService>();
  final _session = locator<SessionService>();

  final _photo = locator<ProfilePhotoService>();
  PhotoPicker picker = PhotoPicker();

  @override
  List<ListenableServiceMixin> get listenableServices => [_photo];

  /// URL firmada de la foto de perfil (null = iniciales).
  String? get photoUrl => _photo.url;

  /// Tiene foto aunque la URL se esté renovando.
  bool get hasPhoto => _photo.hasPhoto;

  /// Mensaje del último intento de cambiar o quitar la foto que no salió.
  String? photoError;

  Future<void> loadPhoto() => _photo.refresh();

  /// Elegir y subir: mientras el selector está abierto o se sube, un segundo
  /// toque se ignora.
  Future<void> changePhoto(PhotoSource source) async {
    if (busy('photo')) return;
    photoError = null;
    setBusyForObject('photo', true);
    try {
      final picked = await picker.pick(source);
      if (picked == null) return;
      final r = await _photo.upload(picked);
      if (!r.ok) photoError = r.message;
    } on PhotoTooLarge {
      photoError = PhotoTooLarge.message;
    } on PhotoUnreadable {
      photoError = PhotoUnreadable.message;
    } catch (_) {
      photoError = 'No pudimos leer la foto. Probá con otra.';
    } finally {
      setBusyForObject('photo', false);
    }
  }

  Future<void> removePhoto() async {
    if (busy('photo')) return;
    photoError = null;
    final r = await runBusyFuture(_photo.remove(), busyObject: 'photo');
    if (!r.ok) photoError = r.message;
    notifyListeners();
  }

  Customer get customer => _customerService.customer;
  String get fullName => customer.fullName;
  String get phoneNumber => customer.phoneNumber;
  String get email => customer.email;

  /// Fila tocada (queda resaltada, como en el perfil de la referencia).
  int? selected;

  /// Texto del último intento de eliminar la cuenta que no salió (null = bien).
  String? deleteError;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  void _select(int i) {
    selected = i;
    notifyListeners();
  }

  Future<void> openPersonalInfo() async {
    _select(0);
    await _nav.navigateToPersonalInfoView();
    notifyListeners();
  }

  Future<void> openChangePassword() {
    _select(1);
    return _nav.navigateToChangePasswordView();
  }

  Future<void> openAddresses() {
    _select(2);
    return _nav.navigateToAddressesView();
  }

  Future<void> openConsumption() {
    _select(4);
    return _nav.navigateToConsumptionView();
  }

  Future<void> openRepurchaseNotice() {
    _select(5);
    return _nav.navigateToRepurchaseNoticeView();
  }

  Future<void> editProfile() async {
    await _nav.navigateToEditProfileView();
    notifyListeners();
  }

  /// Da de baja la cuenta (`DELETE /users/me`). Con pedidos en curso el back
  /// responde 409 y [deleteError] trae el motivo. Devuelve true si se eliminó.
  Future<bool> deleteAccount() async {
    if (isBusy) return false;
    _select(3);
    deleteError = null;
    setBusy(true);
    final result = await _customerService.deleteAccount();
    setBusy(false);
    if (result.status == 401) {
      // La baja pudo haberse hecho y la respuesta perderse: el reintento ya no
      // tiene sesión. Se cierra igual, con un mensaje claro.
      await _session.expire(
          message: 'Tu sesión ya no es válida. Si tu cuenta ya se había '
              'eliminado, no hace falta repetirlo. Si no, volvé a ingresar '
              'e intentá de nuevo.');
      return false;
    }
    if (!result.ok) {
      deleteError = result.message;
      notifyListeners();
      return false;
    }
    await _session.endSession();
    await _nav.clearStackAndShow(Routes.welcomeView);
    return true;
  }
}
