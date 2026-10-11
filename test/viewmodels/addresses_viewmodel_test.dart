import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/ui/views/addresses/addresses_viewmodel.dart';
import 'package:splg_customer/ui/views/address_form/address_form_viewmodel.dart';
import 'package:splg_customer/domain/address_draft.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockCustomerService customers;
  late MockNavigationService nav;

  setUp(() {
    registerServices();
    customers = locator<CustomerService>() as MockCustomerService;
    nav = locator<NavigationService>() as MockNavigationService;
    when(customers.customer).thenReturn(customerWith([
      addr('a', 'Calle 1', primary: true),
      addr('b', 'Calle 2'),
    ]));
  });
  tearDown(() => locator.reset());

  group('AddressesViewModel', () {
    test('carga refrescando las direcciones', () async {
      final m = AddressesViewModel();
      await m.load();
      verify(customers.refreshAddresses()).called(1);
      expect(m.addresses, hasLength(2));
    });

    test('marcar predeterminada llama al servicio; la ya predeterminada no',
        () async {
      when(customers.setDefaultAddress('b'))
          .thenAnswer((_) async => const ApiResult.ok());
      final m = AddressesViewModel();
      await m.setDefault(addr('a', 'Calle 1', primary: true));
      verifyNever(customers.setDefaultAddress('a'));
      await m.setDefault(addr('b', 'Calle 2'));
      verify(customers.setDefaultAddress('b')).called(1);
      expect(m.actionError, isNull);
    });

    test('un error del back al eliminar queda visible', () async {
      when(customers.deleteAddress('b')).thenAnswer((_) async =>
          const ApiResult.fail('No tenés permiso para hacer esto.'));
      final m = AddressesViewModel();
      await m.delete(addr('b', 'Calle 2'));
      expect(m.actionError, 'No tenés permiso para hacer esto.');
      expect(m.isBusy, isFalse);
    });

    test('eliminar con éxito limpia el error', () async {
      when(customers.deleteAddress('b'))
          .thenAnswer((_) async => const ApiResult.ok());
      final m = AddressesViewModel()..actionError = 'viejo';
      await m.delete(addr('b', 'Calle 2'));
      expect(m.actionError, isNull);
      verify(customers.deleteAddress('b')).called(1);
    });
  });

  group('AddressFormViewModel', () {
    test('splitStreet separa calle y número', () {
      expect(AddressFormViewModel.splitStreet('Av. Mitre 1234'),
          ('Av. Mitre', '1234'));
      expect(AddressFormViewModel.splitStreet('Buenos Aires 4114'),
          ('Buenos Aires', '4114'));
      expect(AddressFormViewModel.splitStreet('Ruta 12'), ('Ruta', '12'));
      expect(
          AddressFormViewModel.splitStreet('Sin número'), ('Sin número', ''));
    });

    test('al editar precarga los campos', () {
      final m = AddressFormViewModel(
          address: Address(
              addressId: 'a',
              streetName: 'Buenos Aires 4114',
              city: 'Posadas',
              additionalInstructions: 'Piso 2'));
      expect((m.street.text, m.number.text, m.city.text, m.reference.text),
          ('Buenos Aires', '4114', 'Posadas', 'Piso 2'));
      expect(m.isEditing, isTrue);
    });

    test('valida calle, número y localidad antes de guardar', () async {
      final m = AddressFormViewModel();
      await m.save();
      expect(m.streetError, isNotNull);
      expect(m.numberError, isNotNull);
      expect(m.cityError, isNotNull);
      verifyNever(customers.saveAddress(any, editing: anyNamed('editing')));
    });

    AddressFormViewModel filled() => AddressFormViewModel()
      ..street.text = 'Mitre'
      ..number.text = '100'
      ..city.text = 'Posadas'
      ..reference.text = 'Timbre 2';

    test('guarda el alta y vuelve con true', () async {
      when(customers.saveAddress(any, editing: anyNamed('editing')))
          .thenAnswer((_) async => const ApiResult.ok());
      await filled().save();
      final draft = verify(
              customers.saveAddress(captureAny, editing: anyNamed('editing')))
          .captured
          .single as AddressDraft;
      expect(draft.streetLine, 'Mitre 100');
      expect(draft.query, 'Mitre 100, Posadas, Argentina');
      verify(nav.back(result: true)).called(1);
    });

    test('si no se pudo ubicar muestra el mensaje y no vuelve', () async {
      when(customers.saveAddress(any, editing: anyNamed('editing'))).thenAnswer(
          (_) async => const ApiResult.fail(
              'No pudimos ubicar esa dirección. Revisá la calle, el número y la localidad.'));
      final m = filled();
      await m.save();
      expect(m.errorMessage, contains('No pudimos ubicar'));
      verifyNever(nav.back(result: anyNamed('result')));
      expect(m.isBusy, isFalse);
    });
  });
}
