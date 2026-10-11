import 'dart:async';
import 'dart:math';

import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_lib/permissions/app_permission.dart';

class MapViewModel extends BaseViewModel {
  //final _snackbarService = locator<SnackbarService>();
  final _locationService = locator<LocationService>();
  final _navigationService = locator<NavigationService>();
  final _permissions = locator<AppPermissions>();

  final Completer<GoogleMapController> _controllerComparer = Completer();
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  LatLng? get currentPosition => _currentPosition;

  Placemark? _currentAddress;
  Placemark? get currentAddress => _currentAddress;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// Aviso para mostrar sobre el mapa cuando no hay ubicación (null = sin aviso).
  String? _locationNotice;
  String? get locationNotice => _locationNotice;

  /// true si sólo se puede habilitar desde Ajustes.
  bool get hasLocation => _locationNotice == null && _currentPosition != null;

  bool _canOpenSettings = false;
  bool get canOpenSettings => _canOpenSettings;

  Future<void> initialize() async {
    try {
      final position = await _locationService.getCurrentPosition();
      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationNotice = null;
      _canOpenSettings = false;
      await _getAddressFromLatLng(_currentPosition!);
    } on LocationUnavailableException catch (e) {
      _applyNotice(e);
    } catch (e) {
      _locationNotice =
          'No pudimos obtener tu ubicación. Mové el mapa para elegir la dirección.';
    } finally {
      _isLoading = false;
      rebuildUi();
    }
  }

  void _applyNotice(LocationUnavailableException e) {
    _canOpenSettings = e.outcome == PermissionOutcome.permanentlyDenied;
    _locationNotice = e.serviceDisabled
        ? 'El GPS está apagado. Encendelo o movés el mapa para elegir la dirección.'
        : _canOpenSettings
            ? 'La ubicación está desactivada para SPLG. Podés activarla desde Ajustes o mover el mapa para elegir la dirección.'
            : 'No tenemos permiso de ubicación. Mové el mapa para elegir la dirección.';
  }

  /// Reintenta: vuelve a pedir el permiso (si se puede) y recentra el mapa.
  Future<void> retryLocation() async {
    _isLoading = true;
    rebuildUi();
    await initialize();
  }

  Future<void> openSettings() => _permissions.openSettings();

  void onMapCreated(GoogleMapController controller) {
    _controllerComparer.complete(controller);
    _mapController = controller;
  }

  void onCameraIdle() async {
    if (_mapController == null) return;

    LatLngBounds bounds = await _mapController!.getVisibleRegion();
    LatLng center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    await _getAddressFromLatLng(center);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setBusy(true);
    _currentAddress = await _locationService.getAddressFromLatLng(
      position.latitude,
      position.longitude,
    );
    _currentPosition = position;
    setBusy(false);
  }

  void confirmLocation() {
    if (_currentAddress != null) {
      final address = Address(
        addressId: Random().nextInt(100000).toString(), // Random ID
        streetName: _currentAddress!.street ?? '',
        latitude: '${_currentPosition?.latitude}',
        longitude: '${_currentPosition?.longitude}',
        city: _currentAddress!.locality ?? '',
        postalCode: _currentAddress!.postalCode ?? '',
      );

      _navigationService.back(result: address);
    } else {
      _navigationService.back();
    }
  }
}
