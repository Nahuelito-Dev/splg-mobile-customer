import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/ui/views/checkout/checkout_viewmodel.dart';
import 'package:splg_lib/domain/address.dart';

/// Al confirmar, la app relee las direcciones. La misma dirección puede volver
/// con otros datos (texto armado, indicaciones): eso no tiene que invalidar la
/// cotización, o el botón «Confirmar» vuelve a cotizar en bucle y nunca envía.
void main() {
  final base = Address(
    addressId: 'a1',
    streetName: 'Bolívar 1617',
    latitude: '-27.3671',
    longitude: '-55.8961',
  );

  test('la misma dirección con otro texto o indicaciones no mueve el precio', () {
    final releida = Address(
      addressId: 'a1',
      streetName: 'Bolívar 1617',
      latitude: '-27.3671',
      longitude: '-55.8961',
      formattedAddress: 'Bolívar 1617, Posadas, Misiones',
      additionalInstructions: 'Portón verde',
    );
    expect(releida == base, isFalse);
    expect(CheckoutViewModel.mueveElPrecio(base, releida), isFalse);
  });

  test('otra ubicación o dirección sí mueve el precio', () {
    final movida = Address(
      addressId: 'a1',
      streetName: 'Bolívar 1617',
      latitude: '-27.3700',
      longitude: '-55.8961',
    );
    final otra = Address(addressId: 'a2', streetName: 'Jujuy 571');
    expect(CheckoutViewModel.mueveElPrecio(base, movida), isTrue);
    expect(CheckoutViewModel.mueveElPrecio(base, otra), isTrue);
  });
}
