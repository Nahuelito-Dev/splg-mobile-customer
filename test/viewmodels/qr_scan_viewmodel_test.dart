import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:stacked_services/stacked_services.dart';
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

    group('confirmar la entrega', () {
      late MockOrderTrackingService tracking;
      late MockDialogService dialogs;
      late MockNavigationService navigation;

      BarcodeCapture scan(String code) =>
          BarcodeCapture(barcodes: [Barcode(rawValue: code)]);

      setUp(() {
        tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
        dialogs = locator<DialogService>() as MockDialogService;
        navigation = locator<NavigationService>() as MockNavigationService;
        final customer = locator<CustomerService>() as MockCustomerService;
        when(customer.token).thenAnswer((_) async => 'tok');
      });

      test(
          'el QR bueno confirma la entrega y vuelve con true, sin diálogo de error',
          () async {
        when(tracking.confirmDelivery('o1', 'ABC123', 'tok')).thenAnswer(
            (_) async =>
                const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('ABC123'));

        final titles = verify(dialogs.showDialog(
          title: captureAnyNamed('title'),
          description: anyNamed('description'),
        )).captured;
        expect(titles, ['¡Entrega confirmada!']);
        verify(navigation.back(result: true)).called(1);
      });

      test('un código rechazado muestra el mensaje del back y deja reintentar',
          () async {
        when(tracking.confirmDelivery('o1', 'MAL', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.invalidCode,
                'Código de entrega inválido'));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('MAL'));

        verify(dialogs.showDialog(
          title: 'Código inválido',
          description: 'Código de entrega inválido',
        )).called(1);
        verifyNever(navigation.back(result: anyNamed('result')));
        expect(model.isProcessing, isFalse);
      });

      test('un error de red no se informa como código inválido', () async {
        when(tracking.confirmDelivery('o1', 'ABC123', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.networkError,
                'Sin conexión. Revisá tu internet.'));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('ABC123'));

        verify(dialogs.showDialog(
          title: 'No se pudo confirmar',
          description: 'Sin conexión. Revisá tu internet.',
        )).called(1);
      });

      test(
          'un 401 no muestra otro diálogo ni vuelve atrás: lo atiende la sesión',
          () async {
        when(tracking.confirmDelivery('o1', 'ABC123', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.sessionExpired, 'Tu sesión venció.'));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('ABC123'));

        verifyNever(dialogs.showDialog(
          title: anyNamed('title'),
          description: anyNamed('description'),
        ));
        verifyNever(navigation.back(result: anyNamed('result')));
      });
    });
  });
}
