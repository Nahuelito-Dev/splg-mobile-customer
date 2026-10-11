import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/views/legal/legal_view.dart';
import 'package:splg_customer/ui/widgets/common/account/account_model.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

/// `navigateTo` generado por Stacked pasa más argumentos que la ruta.
Future<dynamic>? _navigatedTo(MockNavigationService nav, String route) =>
    nav.navigateTo(
      route,
      arguments: anyNamed('arguments'),
      id: anyNamed('id'),
      preventDuplicates: anyNamed('preventDuplicates'),
      parameters: anyNamed('parameters'),
      transition: anyNamed('transition'),
    );

void main() {
  group('AccountModel Tests -', () {
    late MockNavigationService navigation;
    late MockCustomerService customers;

    setUp(() {
      registerServices();
      navigation = locator<NavigationService>() as MockNavigationService;
      customers = locator<CustomerService>() as MockCustomerService;
    });
    tearDown(() => locator.reset());

    test('el perfil lleva al login si no hay sesión y al perfil si hay', () {
      when(customers.isUserLoggedIn).thenReturn(false);
      AccountModel().navigateToProfile();
      verify(_navigatedTo(navigation, Routes.loginView)).called(1);

      when(customers.isUserLoggedIn).thenReturn(true);
      AccountModel().navigateToProfile();
      verify(_navigatedTo(navigation, Routes.profileView)).called(1);
    });

    test('términos y privacidad abren cada documento legal', () {
      final model = AccountModel();

      model.navigateToTerms();
      model.navigateToPrivacyPolicy();

      final args = verify(navigation.navigateTo(
        Routes.legalView,
        arguments: captureAnyNamed('arguments'),
        id: anyNamed('id'),
        preventDuplicates: anyNamed('preventDuplicates'),
        parameters: anyNamed('parameters'),
        transition: anyNamed('transition'),
      )).captured.cast<LegalViewArguments>();
      expect(args.map((a) => a.document),
          [LegalDocument.terms, LegalDocument.privacy]);
    });
  });
}
