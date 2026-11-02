import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/bottom_sheets/delivery_code/delivery_code_sheet_model.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockOrderTrackingService tracking;

  setUp(() {
    registerServices();
    tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customer = locator<CustomerService>() as MockCustomerService;
    when(customer.token).thenAnswer((_) async => 'tok');
  });
  tearDown(() => locator.reset());

  group('Ingreso manual del código de entrega -', () {
    test('código bueno: lo manda en mayúsculas y sin espacios', () async {
      when(tracking.confirmDelivery('o1', 'CFE49C3076', 'tok')).thenAnswer(
          (_) async =>
              const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = ' cfe49c 3076 ';

      expect(await model.submit(), isTrue);

      expect(model.errorMessage, isNull);
      verify(tracking.confirmDelivery('o1', 'CFE49C3076', 'tok')).called(1);
    });

    test('código vacío: no llama al back y avisa', () async {
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = '   ';

      expect(await model.submit(), isFalse);

      expect(model.errorMessage, contains('Ingresá el código'));
      verifyNever(tracking.confirmDelivery(any, any, any));
    });

    test('un código de 6 dígitos (pedidos viejos) llega al back', () async {
      when(tracking.confirmDelivery('o1', '482913', 'tok')).thenAnswer(
          (_) async =>
              const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = '482913';

      expect(await model.submit(), isTrue);

      verify(tracking.confirmDelivery('o1', '482913', 'tok')).called(1);
    });

    test('el bloqueo por intentos se muestra en la hoja y no cierra', () async {
      when(tracking.confirmDelivery('o1', '482913', 'tok')).thenAnswer(
          (_) async => const ConfirmDeliveryOutcome(
              ConfirmDeliveryResult.blocked, OrderTrackingService.blockedText));
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = '482913';

      expect(await model.submit(), isFalse);

      expect(model.errorMessage, OrderTrackingService.blockedText);
    });

    test('largo incorrecto: no llama al back', () async {
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = 'ABC';

      expect(await model.submit(), isFalse);

      expect(model.errorMessage, contains('entre 4 y 12'));
      verifyNever(tracking.confirmDelivery(any, any, any));
    });

    test('el back rechaza el código: muestra su mensaje y no cierra', () async {
      when(tracking.confirmDelivery('o1', 'AAAAAAAAAA', 'tok')).thenAnswer(
          (_) async => const ConfirmDeliveryOutcome(
              ConfirmDeliveryResult.invalidCode, 'Código de entrega inválido'));
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = 'aaaaaaaaaa';

      expect(await model.submit(), isFalse);

      expect(model.errorMessage, 'Código de entrega inválido');
      expect(model.isBusy, isFalse);
    });

    test('401: lo atiende la sesión, la hoja no muestra error', () async {
      when(tracking.confirmDelivery('o1', 'AAAAAAAAAA', 'tok')).thenAnswer(
          (_) async => const ConfirmDeliveryOutcome(
              ConfirmDeliveryResult.sessionExpired, 'Tu sesión venció.'));
      final model = DeliveryCodeSheetModel(orderId: 'o1');
      model.codeController.text = 'AAAAAAAAAA';

      expect(await model.submit(), isFalse);

      expect(model.sessionExpired, isTrue);
      expect(model.errorMessage, isNull);
    });
  });
}
