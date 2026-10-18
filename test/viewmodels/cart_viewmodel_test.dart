import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/ui/views/cart/cart_viewmodel.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fake_cart_backend.dart';
import '../helpers/fake_http.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late FakeCartBackend backend;
  late CartService cart;
  late MockNavigationService nav;

  setUp(() {
    registerServices();
    backend = FakeCartBackend();
    cart = TestCart();
    locator.unregister<CartService>();
    locator.registerSingleton<CartService>(cart);
    nav = locator<NavigationService>() as MockNavigationService;
  });
  tearDown(() => locator.reset());

  group('CartViewModel Tests -', () {
    test('al abrir trae el carrito del back (CU-125)', () async {
      await cart.add('g1', 2);
      final m = CartViewModel();
      await m.load();
      expect(m.loadError, isNull);
      expect(m.cart.units, 2);
      expect(m.canContinue, isTrue);
    });

    test('sin conexión al abrir: error claro con reintento', () async {
      backend.failNext = const FakeReply.networkError();
      final m = CartViewModel();
      await m.load();
      expect(m.loadError, ApiErrorText.offline);
      expect(m.canRetry, isTrue);
      await m.load();
      expect(m.loadError, isNull);
    });

    test('sumar, restar y quitar van al back y muestran su resultado',
        () async {
      await cart.add('g1', 1);
      final m = CartViewModel();
      await m.load();

      await m.increment(m.cart.items.single);
      expect(m.cart.quantityOf('g1'), 2);
      await m.decrement(m.cart.items.single);
      expect(m.cart.quantityOf('g1'), 1);
      await m.remove(m.cart.items.single);
      expect(m.cart.isEmpty, isTrue);
      expect(m.canContinue, isFalse);
    });

    test('con una sola unidad restar no llama al back (quitar es otra acción)',
        () async {
      await cart.add('g1', 1);
      final m = CartViewModel();
      await m.load();
      final before = backend.log.length;
      await m.decrement(m.cart.items.single);
      expect(backend.log.length, before);
      expect(m.cart.quantityOf('g1'), 1);
    });

    test('un rechazo del back se muestra y el carrito queda igual', () async {
      await cart.add('g1', 1);
      final m = CartViewModel();
      await m.load();
      backend.failNext =
          const FakeReply(404, {'message': 'El ítem no está en tu carrito'});
      await m.remove(m.cart.items.single);
      expect(m.actionError, isNotNull);
      expect(m.cart.quantityOf('g1'), 1);
      // La próxima acción limpia el error.
      await m.increment(m.cart.items.single);
      expect(m.actionError, isNull);
    });

    test('vaciar deja el carrito vacío', () async {
      await cart.add('g1', 1);
      await cart.add('g2', 1);
      final m = CartViewModel();
      await m.load();
      await m.clear();
      expect(m.cart.isEmpty, isTrue);
      expect(backend.log.last.method, 'DELETE');
      expect(backend.log.last.path, 'cart');
    });

    test('con ítems dados de baja no deja continuar', () async {
      await cart.add('g1', 1);
      await cart.add('g2', 1);
      backend.inactive.add('g2');
      final m = CartViewModel();
      await m.load();
      expect(m.cart.hasUnavailableItems, isTrue);
      expect(m.canContinue, isFalse);
      await m.goToCheckout();
      verifyNever(nav.navigateToCheckoutView());
    });

    test('con el carrito sano continúa a la confirmación', () async {
      await cart.add('g1', 1);
      final m = CartViewModel();
      await m.load();
      await m.goToCheckout();
      verify(nav.navigateToCheckoutView()).called(1);
    });

    test('mientras una acción está en curso otra se ignora', () async {
      await cart.add('g1', 1);
      final m = CartViewModel();
      await m.load();
      final line = m.cart.items.single;
      final a = m.increment(line);
      final b = m.increment(line);
      await Future.wait([a, b]);
      expect(m.cart.quantityOf('g1'), 2);
    });
  });
}
