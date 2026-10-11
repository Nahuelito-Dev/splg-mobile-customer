import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/address.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/address_draft.dart';
import 'package:splg_customer/services/customer_service.dart';

/// Alta o edición de una dirección por formulario: calle, número, localidad y
/// referencia. La ubicación sale del geocoder del dispositivo.
class AddressFormViewModel extends BaseViewModel {
  AddressFormViewModel({this.address}) {
    if (address != null) {
      final (street, number) = splitStreet(address!.streetName);
      this.street.text = street;
      this.number.text = number;
      city.text = address!.city ?? '';
      reference.text = address!.additionalInstructions ?? '';
    }
  }

  final Address? address;

  final _customer = locator<CustomerService>();
  final _nav = locator<NavigationService>();

  final street = TextEditingController();
  final number = TextEditingController();
  final city = TextEditingController();
  final reference = TextEditingController();

  String? streetError;
  String? numberError;
  String? cityError;

  /// Error del servidor o del geocoder, bajo el formulario.
  String? errorMessage;

  bool get isEditing => address != null;

  @override
  void dispose() {
    for (final c in [street, number, city, reference]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "Mitre 123" -> ("Mitre", "123"). Sin número final devuelve todo como calle.
  static (String, String) splitStreet(String line) {
    final m = RegExp(r'^(.*\S)\s+(\d+\S*)$').firstMatch(line.trim());
    return m == null ? (line.trim(), '') : (m.group(1)!, m.group(2)!);
  }

  bool _validate() {
    streetError = street.text.trim().isEmpty ? 'Ingresá la calle.' : null;
    numberError = number.text.trim().isEmpty ? 'Ingresá el número.' : null;
    cityError = city.text.trim().isEmpty ? 'Ingresá la localidad.' : null;
    notifyListeners();
    return streetError == null && numberError == null && cityError == null;
  }

  Future<void> save() async {
    if (isBusy || !_validate()) return;
    errorMessage = null;
    setBusy(true);
    final result = await _customer.saveAddress(
      AddressDraft(
        street: street.text,
        number: number.text,
        city: city.text,
        reference: reference.text,
      ),
      editing: address,
    );
    setBusy(false);
    if (result.ok) {
      // El alta devuelve la dirección creada; la edición, `true`.
      _nav.back(result: result.data ?? true);
    } else {
      errorMessage = result.message;
      notifyListeners();
    }
  }
}
