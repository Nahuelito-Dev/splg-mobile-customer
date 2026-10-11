import 'dart:developer';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:splg_lib/permissions/app_permission.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/app_permissions.dart';

/// No se pudo obtener la posición: [outcome] dice si fue por el permiso (y si
/// se puede volver a pedir o sólo desde Ajustes) o por el GPS apagado.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.outcome,
      {this.serviceDisabled = false});

  final PermissionOutcome outcome;
  final bool serviceDisabled;

  @override
  String toString() =>
      'LocationUnavailableException($outcome, serviceDisabled: $serviceDisabled)';
}

class LocationService {
  AppPermissions get _permissions => locator<AppPermissions>();

  /// Posición actual (ubicación "mientras la app está abierta"). Pide el permiso
  /// en este momento, con explicación previa. Si no se puede, lanza
  /// [LocationUnavailableException]: quien llama sigue funcionando sin ubicación.
  Future<Position> getCurrentPosition() async {
    final outcome = await _permissions.ensure(AppPermission.location);
    if (!outcome.isGranted) {
      throw LocationUnavailableException(outcome);
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationUnavailableException(outcome, serviceDisabled: true);
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Ajustes de ubicación del sistema (para cuando el GPS está apagado).
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<Placemark?> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks[0];
      }
    } catch (e) {
      log('Error getting address from lat/lng: $e');
    }
    return null;
  }
}
