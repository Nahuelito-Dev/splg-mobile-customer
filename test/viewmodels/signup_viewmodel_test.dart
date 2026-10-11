import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/common/app_strings.dart';
import 'package:splg_customer/ui/views/signup/signup_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('SignupViewModel Tests -', () {
    late MockCustomerService customers;
    late MockDialogService dialogs;

    setUp(() {
      registerServices();
      customers = locator<CustomerService>() as MockCustomerService;
      dialogs = locator<DialogService>() as MockDialogService;
    });
    tearDown(() => locator.reset());

    SignupViewModel filled() => SignupViewModel()
      ..formValueMap['name'] = 'QA'
      ..formValueMap['email'] = 'qa@splg.com'
      ..formValueMap['password'] = 'Test1234'
      ..formValueMap['phone'] = '3815550999';

    void stubRegister(RegisterOutcome outcome) {
      when(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
      )).thenAnswer((_) async => outcome);
    }

    test('email o teléfono repetidos muestran un mensaje específico', () async {
      stubRegister(RegisterOutcome.alreadyExists);

      await filled().onRegister();

      verify(dialogs.showDialog(
        title: signupViewErrorDialogTitle,
        description: signupViewAlreadyExistsDescription,
      )).called(1);
    });

    test('un fallo cualquiera muestra el mensaje genérico', () async {
      stubRegister(RegisterOutcome.failed);

      await filled().onRegister();

      verify(dialogs.showDialog(
        title: signupViewErrorDialogTitle,
        description: signupViewErrorDialogDescription,
      )).called(1);
    });
  });
}
