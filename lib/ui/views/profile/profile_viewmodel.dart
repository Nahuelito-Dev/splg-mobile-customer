import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/customer.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/session_service.dart';

class ProfileViewModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();
  final _nav = locator<NavigationService>();
  final _session = locator<SessionService>();

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
