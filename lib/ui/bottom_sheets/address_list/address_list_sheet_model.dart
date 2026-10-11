import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/services/customer_service.dart';

class AddressListSheetModel extends BaseViewModel {
  /// Valor de `SheetResponse.data` cuando el usuario toca "Agregar dirección".
  static const addNew = 'add-address';

  final _customerService = locator<CustomerService>();

  List<Address> get addresses => _customerService.customer.addresses;

  /// Id de la dirección ya elegida; sin elegida, la predeterminada.
  bool isSelected(Address a, String? selectedId) =>
      selectedId != null ? a.addressId == selectedId : a.primary;

  void selectAddress(
      Address address, Function(SheetResponse response) completer) {
    completer(SheetResponse(confirmed: true, data: address));
  }

  void addAddress(Function(SheetResponse response) completer) {
    completer(SheetResponse(confirmed: false, data: addNew));
  }
}
