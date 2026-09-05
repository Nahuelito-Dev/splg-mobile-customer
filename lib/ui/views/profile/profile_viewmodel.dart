import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';

import 'package:splg_lib/domain/customer.dart';
import 'package:splg_lib/domain/address.dart';

class ProfileViewModel extends BaseViewModel {
  final _dialogService = locator<DialogService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();

  String get email => customer.email;
  String get fullName => customer.fullName;
  String get phoneNumber => customer.phoneNumber;
  Customer get customer => _customerService.customer;

  Address? get primaryAddress {
    final addresses = customer.addresses;
    if (addresses.isEmpty) return null;

    try {
      return addresses.firstWhere((addr) => addr.primary == true);
    } catch (_) {
      return null;
    }
  }

  String get formattedAddress {
    final address = primaryAddress;
    if (address == null) return 'Sin dirección';

    final parts = <String>[];
    if (address.streetName.isNotEmpty) {
      parts.add(address.streetName);
    }
    if (address.city != null && address.city!.isNotEmpty) {
      parts.add(address.city!);
    }

    return parts.isEmpty ? 'Sin dirección' : parts.join(', ');
  }

  /// Actualiza el nombre contra el backend y refresca la UI.
  Future<bool> updateName(String name) async {
    final ok = await _customerService.updateProfile(fullName: name);
    if (ok) notifyListeners();
    return ok;
  }

  /// Actualiza el teléfono contra el backend y refresca la UI.
  Future<bool> updatePhone(String phone) async {
    final ok = await _customerService.updateProfile(phoneNumber: phone);
    if (ok) notifyListeners();
    return ok;
  }

  Future<void> navigateToAddresses() async {
    await _navigationService.navigateToAddressesView();
    // Al volver, refrescamos por si cambió la dirección predeterminada.
    notifyListeners();
  }

  Future<void> navigateToTerms() async {
    await _navigationService.navigateToLegalView(
      document: LegalDocument.terms,
    );
  }

  Future<void> navigateToPrivacyPolicy() async {
    await _navigationService.navigateToLegalView(
      document: LegalDocument.privacy,
    );
  }

  Future<void> signOut() async {
    final response = await _dialogService.showConfirmationDialog(
      title: 'Cerrar sesión',
      description: '¿Estás seguro que deseas cerrar sesión?',
      confirmationTitle: 'Cerrar sesión',
      cancelTitle: 'Cancelar',
    );

    if (response?.confirmed == true) {
      await _customerService.signOut();
      _navigationService.clearStackAndShow(Routes.homeView);
    }
  }

  Future<void> deleteAccount() async {
    final response = await _dialogService.showConfirmationDialog(
      title: 'Borrar cuenta',
      description:
          '¿Estás seguro que deseas borrar tu cuenta? Esta acción no se puede deshacer.',
      confirmationTitle: 'Borrar cuenta',
      cancelTitle: 'Cancelar',
      dialogPlatform: DialogPlatform.Material,
    );

    if (response?.confirmed == true) {
      await _customerService.signOut();
      _navigationService.clearStackAndShow(Routes.loginView);
    }
  }
}
