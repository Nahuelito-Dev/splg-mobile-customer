import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/address.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Mis direcciones: lista, alta, edición, baja y predeterminada.
class AddressesViewModel extends LoadViewModel {
  final _customerService = locator<CustomerService>();
  final _nav = locator<NavigationService>();

  List<Address> get addresses => _customerService.customer.addresses;

  /// Error de la última acción (baja, predeterminada).
  String? actionError;

  @override
  Future<void> fetch() => _customerService.refreshAddresses();

  Future<void> add() async {
    await _nav.navigateToAddressFormView();
    notifyListeners();
  }

  Future<void> edit(Address address) async {
    await _nav.navigateToAddressFormView(address: address);
    notifyListeners();
  }

  Future<void> setDefault(Address address) async {
    if (address.primary || isBusy) return;
    setBusy(true);
    final r = await _customerService.setDefaultAddress(address.addressId);
    actionError = r.ok ? null : r.message;
    setBusy(false);
  }

  Future<void> delete(Address address) async {
    if (isBusy) return;
    setBusy(true);
    final r = await _customerService.deleteAddress(address.addressId);
    actionError = r.ok ? null : r.message;
    setBusy(false);
  }
}
