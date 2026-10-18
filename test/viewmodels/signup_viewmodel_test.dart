import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/views/signup/signup_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('SignupViewModel Tests -', () {
    late MockCustomerService customers;
    late MockNavigationService nav;

    setUp(() {
      registerServices();
      customers = locator<CustomerService>() as MockCustomerService;
      nav = locator<NavigationService>() as MockNavigationService;
    });
    tearDown(() => locator.reset());

    SignupViewModel atStep2() {
      final m = SignupViewModel();
      m.name.text = 'QA Test';
      m.phone.text = '381 555-0999';
      m.next();
      m.email.text = 'qa@splg.com';
      m.password.text = 'Test1234';
      m.repeat.text = 'Test1234';
      m.setTerms(true);
      m.setPrivacy(true);
      return m;
    }

    /// Con el paso 3 (consumo, opcional) a la vista.
    Future<SignupViewModel> atStep3() async {
      final m = atStep2();
      await m.next();
      return m;
    }

    void stubRegister(RegisterOutcome outcome) {
      when(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: anyNamed('consumption'),
      )).thenAnswer((_) async => outcome);
    }

    test('el paso 1 valida nombre y teléfono antes de avanzar', () async {
      final m = SignupViewModel();
      await m.next();
      expect(m.step, 0);
      expect(m.nameError, isNotNull);
      expect(m.phoneError, isNotNull);

      m.name.text = 'QA Test';
      m.phone.text = '3815550999';
      await m.next();
      expect(m.step, 1);
      expect(m.nameError, isNull);
    });

    test('volver desde el paso 2 regresa al 1; desde el 1 sale', () async {
      final m = atStep2();
      expect(m.step, 1);
      await m.back();
      expect(m.step, 0);
      await m.back();
      verify(nav.back()).called(1);
    });

    test('el paso 2 pide política de contraseña, coincidencia y casillas',
        () async {
      final m = atStep2();
      m.password.text = 'corta';
      m.repeat.text = 'otra';
      m.setTerms(false);
      await m.next();
      expect(m.passwordError, isNotNull);
      expect(m.repeatError, 'Las contraseñas no coinciden.');
      expect(m.generalError, contains('aceptá'));
      verifyNever(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: anyNamed('consumption'),
      ));
    });

    test('registra con el teléfono en E.164, inicia sesión y va al final',
        () async {
      stubRegister(RegisterOutcome.created);
      when(customers.signIn(any, any))
          .thenAnswer((_) async => SignInOutcome.ok);
      final notifications =
          locator<NotificationService>() as MockNotificationService;

      await (await atStep3()).next();

      verify(customers.registerCustomer(
        name: 'QA Test',
        email: 'qa@splg.com',
        password: 'Test1234',
        phoneNumber: '+543815550999',
        consumption: null,
      )).called(1);
      verify(customers.signIn('qa@splg.com', 'Test1234')).called(1);
      verify(notifications.requestPermissionAndRegister()).called(1);
      verify(nav.clearStackAndShow(Routes.signupDoneView)).called(1);
    });

    test('email o teléfono repetidos muestran un mensaje específico', () async {
      stubRegister(RegisterOutcome.alreadyExists);
      final m = await atStep3();
      await m.next();
      expect(m.generalError, contains('dada de baja o ya registrada'));
      expect(m.generalError, contains('contactá a tu distribuidora'));
      expect(m.isBusy, isFalse);
      verifyNever(nav.clearStackAndShow(any));
    });

    test('si después del alta falla el inicio de sesión no avanza al final',
        () async {
      stubRegister(RegisterOutcome.created);
      when(customers.signIn(any, any))
          .thenAnswer((_) async => SignInOutcome.failed);
      final notifications =
          locator<NotificationService>() as MockNotificationService;
      final dialogs = locator<DialogService>() as MockDialogService;

      await (await atStep3()).next();

      verifyNever(nav.clearStackAndShow(Routes.signupDoneView));
      verifyNever(notifications.requestPermissionAndRegister());
      verify(dialogs.showDialog(
        title: 'Cuenta creada',
        description: anyNamed('description'),
        buttonTitle: 'Aceptar',
      )).called(1);
      verify(nav.clearStackAndShow(Routes.loginView)).called(1);
    });

    test('un fallo cualquiera muestra el mensaje genérico', () async {
      stubRegister(RegisterOutcome.failed);
      final m = await atStep3();
      await m.next();
      expect(m.generalError, contains('No pudimos completar el registro'));
    });

    test('el paso 2 avanza al paso 3 (consumo) sin registrar todavía',
        () async {
      final m = atStep2();
      await m.next();
      expect(m.step, 2);
      verifyNever(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: anyNamed('consumption'),
      ));
    });

    test('"Omitir" registra sin consumo', () async {
      stubRegister(RegisterOutcome.created);
      when(customers.signIn(any, any))
          .thenAnswer((_) async => SignInOutcome.ok);
      final m = await atStep3();
      await m.skipConsumption();
      verify(customers.registerCustomer(
        name: 'QA Test',
        email: 'qa@splg.com',
        password: 'Test1234',
        phoneNumber: '+543815550999',
        consumption: null,
      )).called(1);
    });

    test('declarar a medias pide completar y no registra', () async {
      final m = await atStep3();
      m.consumptionQuantity.text = '2';
      await m.next();
      expect(m.consumptionError, contains('garrafa habitual'));
      m.selectConsumptionCylinder('g1');
      m.consumptionQuantity.text = 'abc';
      await m.next();
      expect(m.consumptionError, contains('cuántas garrafas'));
      verifyNever(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: anyNamed('consumption'),
      ));
    });

    test('registra con el consumo declarado (coma decimal)', () async {
      stubRegister(RegisterOutcome.created);
      when(customers.signIn(any, any))
          .thenAnswer((_) async => SignInOutcome.ok);
      final m = await atStep3();
      m.selectConsumptionCylinder('g1');
      m.consumptionQuantity.text = '1,5';
      await m.next();
      final sent = verify(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: captureAnyNamed('consumption'),
      )).captured.single as ConsumptionDeclaration;
      expect(sent.cylinderTypeId, 'g1');
      expect(sent.quantityPerMonth, 1.5);
      expect(sent.confirmOutOfRange, isFalse);
    });

    test('fuera de rango pide confirmación y reenvía con confirmOutOfRange',
        () async {
      final dialogs = locator<DialogService>() as MockDialogService;
      when(dialogs.showConfirmationDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        confirmationTitle: anyNamed('confirmationTitle'),
        cancelTitle: anyNamed('cancelTitle'),
      )).thenAnswer((_) async => DialogResponse(confirmed: true));
      var calls = 0;
      when(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: anyNamed('consumption'),
      )).thenAnswer((_) async => ++calls == 1
          ? RegisterOutcome.consumptionOutOfRange
          : RegisterOutcome.created);
      when(customers.signIn(any, any))
          .thenAnswer((_) async => SignInOutcome.ok);
      final m = await atStep3();
      m.selectConsumptionCylinder('g1');
      m.consumptionQuantity.text = '900';
      await m.next();
      final sent = verify(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: captureAnyNamed('consumption'),
      )).captured.cast<ConsumptionDeclaration>();
      expect(sent.map((d) => d.confirmOutOfRange), [false, true]);
      verify(nav.clearStackAndShow(Routes.signupDoneView)).called(1);
    });

    test('fuera de rango y el cliente corrige: no se reenvía', () async {
      final dialogs = locator<DialogService>() as MockDialogService;
      when(dialogs.showConfirmationDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        confirmationTitle: anyNamed('confirmationTitle'),
        cancelTitle: anyNamed('cancelTitle'),
      )).thenAnswer((_) async => DialogResponse(confirmed: false));
      stubRegister(RegisterOutcome.consumptionOutOfRange);
      final m = await atStep3();
      m.selectConsumptionCylinder('g1');
      m.consumptionQuantity.text = '900';
      await m.next();
      verify(customers.registerCustomer(
        name: anyNamed('name'),
        email: anyNamed('email'),
        password: anyNamed('password'),
        phoneNumber: anyNamed('phoneNumber'),
        consumption: anyNamed('consumption'),
      )).called(1);
      verifyNever(nav.clearStackAndShow(Routes.signupDoneView));
      expect(m.isBusy, isFalse);
    });

    test('la política de contraseña', () {
      expect(SignupViewModel.meetsPolicy('Test1234'), isTrue);
      expect(SignupViewModel.meetsPolicy('test1234'), isFalse);
      expect(SignupViewModel.meetsPolicy('Test'), isFalse);
    });
  });
}
