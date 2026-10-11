import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';

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

  void navigateToTerms() {
    _navigationService.navigateToLegalView(document: LegalDocument.terms);
  }

  void navigateToPrivacyPolicy() {
    _navigationService.navigateToLegalView(document: LegalDocument.privacy);
  }
}
