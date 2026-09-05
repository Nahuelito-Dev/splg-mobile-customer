import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';

class AccountModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();

  void navigateToProfile() {
    if (_customerService.isUserLoggedIn) {
      _navigationService.navigateToProfileView();
    } else {
      _navigationService.navigateToLoginView();
    }
  }
}
