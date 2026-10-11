/// Lo que el cliente escribe en el formulario de dirección.
class AddressDraft {
  const AddressDraft({
    required this.street,
    required this.number,
    required this.city,
    this.reference = '',
  });

  final String street;
  final String number;
  final String city;
  final String reference;

  /// "Mitre 123": lo que se guarda en `street`.
  String get streetLine => '${street.trim()} ${number.trim()}'.trim();

  /// Texto para el geocoder.
  String get query => '$streetLine, ${city.trim()}, Argentina';
}
