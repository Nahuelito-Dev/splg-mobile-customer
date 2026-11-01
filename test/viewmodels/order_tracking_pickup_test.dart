import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/cylinder_recovery_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/views/order_tracking/order_tracking_viewmodel.dart';

import '../helpers/fake_m3_m5_services.dart';
import '../helpers/fixtures.dart';
import '../helpers/m3_m5_fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCylinderRecoveryService recovery;

  setUp(() {
    registerServices();
    final tracking = locator<OrderTrackingService>() as MockOrderTrackingService;
    final customers = locator<CustomerService>() as MockCustomerService;
    when(customers.token).thenAnswer((_) async => 'tok');
    when(customers.customer).thenReturn(customerWith());
    when(tracking.fetchOrderById('o1', 'tok'))
        .thenAnswer((_) async => {'status': 'accepted'});
    when(tracking.fetchDriverPhoto('o1', 'tok'))
        .thenAnswer((_) async => const DriverPhotoLookup());
    recovery = locator<CylinderRecoveryService>() as FakeCylinderRecoveryService;
  });
  tearDown(() => locator.reset());

  Future<OrderTrackingViewModel> opened() async {
    final m = OrderTrackingViewModel(orderId: 'o1');
    await m.initialize();
    await Future<void>.delayed(Duration.zero);
    return m;
  }

  group('Seguimiento con retiro de envase (M5) -', () {
    test('el pedido que lleva un retiro aceptado avisa cuál envase dejar listo',
        () async {
      recovery.mineResult = ApiResult.ok([
        recoveryCase(pickup: pickupJson(status: 'accepted', orderId: 'o1')),
      ]);
      final m = await opened();
      expect(m.pickupNotice, contains('SPLG-00197'));
      expect(m.pickupNotice, contains('retira'));
      m.dispose();
    });

    test('un retiro de otro pedido no se avisa acá', () async {
      recovery.mineResult = ApiResult.ok([
        recoveryCase(pickup: pickupJson(status: 'accepted', orderId: 'otro')),
      ]);
      final m = await opened();
      expect(m.pickupNotice, isNull);
      m.dispose();
    });

    test('una oferta todavía sin aceptar no es un retiro', () async {
      recovery.mineResult = ApiResult.ok([
        recoveryCase(pickup: pickupJson(orderId: 'o1')),
      ]);
      final m = await opened();
      expect(m.pickupNotice, isNull);
      m.dispose();
    });

    test('sin casos (módulo apagado) no hay aviso', () async {
      final m = await opened();
      expect(m.pickupNotice, isNull);
      m.dispose();
    });

    test('si falla leer los casos el seguimiento sigue normal', () async {
      recovery.mineResult = const ApiResult.fail('Sin conexión.');
      final m = await opened();
      expect(m.pickupNotice, isNull);
      expect(m.hasOrderLoaded, isTrue);
      m.dispose();
    });
  });
}
