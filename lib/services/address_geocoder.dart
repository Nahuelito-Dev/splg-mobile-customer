import 'dart:developer';

import 'package:geocoding/geocoding.dart';

/// Un punto del mapa.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Dentro de rango y no el 0,0 que algunos geocoders devuelven al no ubicar.
  bool get isUsable =>
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);
}

/// Convierte una dirección escrita en coordenadas.
abstract interface class AddressGeocoder {
  Future<GeoPoint?> locate(String query);
}

/// Usa el geocoder del dispositivo (paquete `geocoding`).
class DeviceAddressGeocoder implements AddressGeocoder {
  const DeviceAddressGeocoder();

  @override
  Future<GeoPoint?> locate(String query) async {
    try {
      final found = await locationFromAddress(query);
      if (found.isEmpty) return null;
      final point = GeoPoint(found.first.latitude, found.first.longitude);
      return point.isUsable ? point : null;
    } catch (e) {
      log('geocoding falló: $e');
      return null;
    }
  }
}
