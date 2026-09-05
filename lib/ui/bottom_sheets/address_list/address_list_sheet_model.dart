import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/services/customer_service.dart';

class AddressListSheetModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();

  List<Address> get addresses => _customerService.customer.addresses;

  void selectAddress(
      Address address, Function(SheetResponse response) completer) {
    completer(SheetResponse(confirmed: true, data: address));
  }
}
