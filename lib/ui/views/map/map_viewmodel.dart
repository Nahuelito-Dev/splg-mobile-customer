import 'dart:async';
import 'dart:math';

import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/location_service.dart';

class MapViewModel extends BaseViewModel {
  //final _snackbarService = locator<SnackbarService>();
  final _locationService = locator<LocationService>();
  final _navigationService = locator<NavigationService>();

  final Completer<GoogleMapController> _controllerComparer = Completer();
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  LatLng? get currentPosition => _currentPosition;

  Placemark? _currentAddress;
  Placemark? get currentAddress => _currentAddress;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    try {
      final position = await _locationService.getCurrentPosition();
      _currentPosition = LatLng(position.latitude, position.longitude);
      await _getAddressFromLatLng(_currentPosition!);
    } catch (e) {
      //_snackbarService.showSnackbar(message: 'Error al obtener la ubicación.');
    } finally {
      _isLoading = false;
      rebuildUi();
    }
  }

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
