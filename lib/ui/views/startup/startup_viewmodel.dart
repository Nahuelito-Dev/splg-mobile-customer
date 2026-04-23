import 'package:stacked/stacked.dart';
import 'package:jennigas_customer/app/app.router.dart';
import 'package:jennigas_customer/app/app.locator.dart';

import 'package:stacked_services/stacked_services.dart';
import 'package:jennigas_customer/services/customer_service.dart';

class StartupViewModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();

  // Place anything here that needs to happen before we get into the application
  Future runStartupLogic() async {
    if (_customerService.isUserLoggedIn) {
      bool success = false;

      // Keep trying until successful or user cancels
      while (!success) {
        success = await _customerService.init();

        if (!success) {
          // Session was invalidated (for example, user removed in Firebase).
          // Continue as guest without blocking startup.
          if (!_customerService.isUserLoggedIn) {
            break;
          }

          // Show error dialog with retry option
          final response = await _dialogService.showDialog(
            title: 'Error de Inicio de Sesión',
            description:
                'No se pudo iniciar sesión. Por favor, verifica tu conexión a internet e intenta nuevamente.',
            buttonTitle: 'Reintentar',
            cancelTitle: 'Cancelar',
          );

          // If user cancelled, continue as guest.
          if (response?.confirmed != true) {
            await _customerService.signOut();
            break;
          }
          // If confirmed, loop will retry
        }
      }
    }

    _navigationService.replaceWithHomeView();
  }
}
