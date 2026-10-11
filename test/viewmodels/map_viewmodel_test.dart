import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/ui/views/map/map_viewmodel.dart';
import 'package:splg_lib/permissions/app_permission.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('MapViewModel Tests -', () {
    late MockLocationService location;

    setUp(() {
      registerServices();
      location = locator<LocationService>() as MockLocationService;
    });
    tearDown(() => locator.reset());

    test('sin permiso (se puede reintentar): avisa y ofrece reintentar',
        () async {
      when(location.getCurrentPosition()).thenThrow(
          const LocationUnavailableException(PermissionOutcome.denied));
      final model = MapViewModel();

      await model.initialize();

      expect(model.locationNotice, contains('permiso de ubicación'));
      expect(model.canOpenSettings, isFalse);
      expect(model.hasLocation, isFalse);
      expect(model.isLoading, isFalse, reason: 'el mapa no queda cargando');
    });

    test('denegado para siempre: ofrece Ajustes', () async {
      when(location.getCurrentPosition()).thenThrow(
          const LocationUnavailableException(
              PermissionOutcome.permanentlyDenied));
      final model = MapViewModel();

      await model.initialize();

      expect(model.locationNotice, contains('Ajustes'));
      expect(model.canOpenSettings, isTrue);
    });

    test('GPS apagado: lo dice', () async {
      when(location.getCurrentPosition()).thenThrow(
          const LocationUnavailableException(PermissionOutcome.granted,
              serviceDisabled: true));
      final model = MapViewModel();

      await model.initialize();

      expect(model.locationNotice, contains('GPS'));
    });

    test('un error inesperado tampoco deja la pantalla cargando', () async {
      when(location.getCurrentPosition()).thenThrow(StateError('plugin'));
      final model = MapViewModel();

      await model.initialize();

      expect(model.locationNotice, isNotNull);
      expect(model.isLoading, isFalse);
    });
  });
}
