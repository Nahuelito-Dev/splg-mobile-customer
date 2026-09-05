import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/address.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';

class AddressesViewModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();

  List<Address> get addresses => _customerService.customer.addresses;

  String? actionError;

  Future<void> initialize() async {
    setBusy(true);
    await _customerService.refreshAddresses();
    setBusy(false);
  }

  /// Abre el mapa para elegir una nueva dirección y, si se eligió, la crea.
  Future<void> addAddress() async {
    final result = await _navigationService.navigateToMapView();
    if (result is! Address) return;

    setBusy(true);
    final ok = await _customerService.createAndSyncAddress(result);
    actionError = ok ? null : 'No se pudo guardar la dirección.';
    setBusy(false);
  }

  Future<void> setDefault(Address address) async {
    if (address.primary) return;
    setBusy(true);
    final ok = await _customerService.setDefaultAddress(address.addressId);
    actionError = ok ? null : 'No se pudo marcar como predeterminada.';
    setBusy(false);
  }

  Future<void> deleteAddress(Address address) async {
    setBusy(true);
    final ok = await _customerService.deleteAddress(address.addressId);
    actionError = ok ? null : 'No se pudo eliminar la dirección.';
    setBusy(false);
  }
}
