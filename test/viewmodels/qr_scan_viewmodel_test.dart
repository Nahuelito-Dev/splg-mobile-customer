import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_customer/ui/views/qr_scan/qr_scan_viewmodel.dart';
import 'package:splg_lib/permissions/app_permission.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QrScanViewModel Tests -', () {
    late MockAppPermissions permissions;

    setUp(() {
      registerServices();
      permissions = locator<AppPermissions>() as MockAppPermissions;
    });
    tearDown(() => locator.reset());

    test('pide la cámara al abrir y, concedida, no queda bloqueada', () async {
      when(permissions.ensure(AppPermission.camera))
          .thenAnswer((_) async => PermissionOutcome.granted);
      final model = QrScanViewModel(orderId: 'o1');

      await model.initialize();

      verify(permissions.ensure(AppPermission.camera)).called(1);
      expect(model.cameraGranted, isTrue);
    });

    test('denegada: muestra el estado (sin abrir la cámara) y deja reintentar',
        () async {
      when(permissions.ensure(AppPermission.camera))
          .thenAnswer((_) async => PermissionOutcome.denied);
      final model = QrScanViewModel(orderId: 'o1');

      await model.initialize();
      expect(model.cameraGranted, isFalse);
      expect(model.cameraNeedsSettings, isFalse);

      await model.retryCamera();
      verify(permissions.ensure(AppPermission.camera)).called(2);
    });

    test('denegada para siempre: manda a Ajustes', () async {
      when(permissions.ensure(AppPermission.camera))
          .thenAnswer((_) async => PermissionOutcome.permanentlyDenied);
      final model = QrScanViewModel(orderId: 'o1');

      await model.initialize();
      await model.openSettings();

      expect(model.cameraNeedsSettings, isTrue);
      verify(permissions.openSettings()).called(1);
    });
  });
}
