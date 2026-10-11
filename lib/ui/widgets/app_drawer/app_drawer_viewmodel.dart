import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/session_service.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';

/// Navegación del menú lateral: cada ítem abre su pantalla.
class AppDrawerViewModel extends BaseViewModel {
  final _nav = locator<NavigationService>();
  final _session = locator<SessionService>();

  Future<void> openProfile() => _nav.navigateToProfileView();
  Future<void> openOrders() => _nav.navigateToOrdersView();
  Future<void> openAddresses() => _nav.navigateToAddressesView();
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
