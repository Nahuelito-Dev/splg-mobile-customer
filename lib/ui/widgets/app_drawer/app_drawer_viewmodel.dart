import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';
import 'package:splg_customer/services/profile_photo_service.dart';
import 'package:splg_customer/services/session_service.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';

/// Navegación del menú lateral: cada ítem abre su pantalla.
class AppDrawerViewModel extends ReactiveViewModel {
  final _nav = locator<NavigationService>();
  final _session = locator<SessionService>();

  final _photo = locator<ProfilePhotoService>();
  final _customer = locator<CustomerService>();
  final _recovery = locator<CylinderRecoveryService>();

  /// Tiene envases sin devolver: sólo entonces el menú muestra la entrada
  /// (con el módulo apagado nunca aparece).
  bool hasRecoveryCases = false;

  @override
  List<ListenableServiceMixin> get listenableServices => [_photo];

  String? get photoUrl => _photo.url;
  String get fullName => _customer.customer.fullName;

  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  Future<void> loadPhoto() => _photo.refresh();

  /// Lee en silencio si hay envases para devolver; si falla, la entrada queda
  /// oculta.
  Future<void> loadRecovery() async {
    try {
      final r = await _recovery.mine();
      hasRecoveryCases = r.ok && r.data!.isNotEmpty;
    } catch (_) {
      hasRecoveryCases = false;
    }
    notifyListeners();
  }

  Future<void> openProfile() => _nav.navigateToProfileView();
  Future<void> openOrders() => _nav.navigateToOrdersView();
  Future<void> openAddresses() => _nav.navigateToAddressesView();
  Future<void> openCylinderRecovery() => _nav.navigateToCylinderRecoveryView();
  Future<void> openClaims() => _nav.navigateToClaimsView();
  Future<void> openNotifications() => _nav.navigateToNotificationsView();
  Future<void> openHelp() => _nav.navigateToHelpView();
  Future<void> openTerms() =>
      _nav.navigateToLegalView(document: LegalDocument.terms);
  Future<void> openPrivacy() =>
      _nav.navigateToLegalView(document: LegalDocument.privacy);
  Future<void> openAbout() => _nav.navigateToAboutView();

  Future<void> logout() => _session.logout();
}
