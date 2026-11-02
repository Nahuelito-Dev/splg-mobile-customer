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
        when(tracking.confirmDelivery('o1', 'A1B2C3D4E5', 'tok')).thenAnswer(
            (_) async =>
                const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('A1B2C3D4E5'));

        final titles = verify(dialogs.showDialog(
          title: captureAnyNamed('title'),
          description: anyNamed('description'),
        )).captured;
        expect(titles, ['¡Entrega confirmada!']);
        verify(navigation.back(result: true)).called(1);
      });

      test('un código rechazado muestra el mensaje del back y deja reintentar',
          () async {
        when(tracking.confirmDelivery('o1', '0123456789', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.invalidCode,
                'Código de entrega inválido'));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('0123456789'));

        verify(dialogs.showDialog(
          title: 'Código inválido',
          description: 'Código de entrega inválido',
        )).called(1);
        verifyNever(navigation.back(result: anyNamed('result')));
        expect(model.isProcessing, isFalse);
      });

      test('un código de 6 dígitos (pedidos viejos) llega al back', () async {
        when(tracking.confirmDelivery('o1', '482913', 'tok')).thenAnswer(
            (_) async =>
                const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('482913'));

        verify(tracking.confirmDelivery('o1', '482913', 'tok')).called(1);
        verify(navigation.back(result: true)).called(1);
      });

      test('un QR que no tiene forma de código no se manda al back', () async {
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('https://example.com/menu'));

        verifyNever(tracking.confirmDelivery(any, any, any));
        verify(dialogs.showDialog(
          title: 'No pudimos leer el código',
          description: OrderTrackingService.malformedCodeText,
        )).called(1);
        expect(model.isProcessing, isFalse);
      });

      test('entre varios QR en el cuadro manda el que tiene forma de código',
          () async {
        when(tracking.confirmDelivery('o1', 'A1B2C3D4E5', 'tok')).thenAnswer(
            (_) async =>
                const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(BarcodeCapture(barcodes: [
          Barcode(rawValue: 'https://example.com'),
          Barcode(rawValue: 'a1b2c3d4e5'),
        ]));

        verify(tracking.confirmDelivery('o1', 'A1B2C3D4E5', 'tok')).called(1);
        verify(navigation.back(result: true)).called(1);
      });

      test(
          'la misma lectura rechazada se ignora un rato y después se reintenta',
          () async {
        var now = DateTime(2026, 11, 1, 20);
        when(tracking.confirmDelivery('o1', '0123456789', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.invalidCode,
                'Código de entrega inválido'));
        final model = QrScanViewModel(orderId: 'o1', clock: () => now);

        await model.onDetect(scan('0123456789'));
        now = now.add(const Duration(seconds: 1));
        await model.onDetect(scan('0123456789'));
        verify(tracking.confirmDelivery('o1', '0123456789', 'tok')).called(1);

        now = now.add(QrScanViewModel.repeatedReadingWindow);
        await model.onDetect(scan('0123456789'));
        verify(tracking.confirmDelivery('o1', '0123456789', 'tok')).called(1);
      });

      test('si el back dice que es de otro pedido, lo explica', () async {
        when(tracking.confirmDelivery('o1', '0123456789', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.otherOrder,
                OrderTrackingService.otherOrderText));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('0123456789'));

        verify(dialogs.showDialog(
          title: 'Es el QR de otro pedido',
          description: OrderTrackingService.otherOrderText,
        )).called(1);
        verifyNever(navigation.back(result: anyNamed('result')));
      });

      test('con el código bloqueado avisa que pida uno nuevo al chofer',
          () async {
        when(tracking.confirmDelivery('o1', '482913', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.blocked,
                OrderTrackingService.blockedText));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('482913'));

        verify(dialogs.showDialog(
          title: 'Código bloqueado',
          description: OrderTrackingService.blockedText,
        )).called(1);
        verifyNever(navigation.back(result: anyNamed('result')));
      });

      test('un error de red no se informa como código inválido', () async {
        when(tracking.confirmDelivery('o1', 'A1B2C3D4E5', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.networkError,
                'Sin conexión. Revisá tu internet.'));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('A1B2C3D4E5'));

        verify(dialogs.showDialog(
          title: 'No se pudo confirmar',
          description: 'Sin conexión. Revisá tu internet.',
        )).called(1);
      });

      test(
          'un 401 no muestra otro diálogo ni vuelve atrás: lo atiende la sesión',
          () async {
        when(tracking.confirmDelivery('o1', 'A1B2C3D4E5', 'tok')).thenAnswer(
            (_) async => const ConfirmDeliveryOutcome(
                ConfirmDeliveryResult.sessionExpired, 'Tu sesión venció.'));
        final model = QrScanViewModel(orderId: 'o1');

        await model.onDetect(scan('A1B2C3D4E5'));

        verifyNever(dialogs.showDialog(
          title: anyNamed('title'),
          description: anyNamed('description'),
        ));
        verifyNever(navigation.back(result: anyNamed('result')));
      });
    });
  });
}
