import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_lib/network/api_error_text.dart';

import '../helpers/fake_cart_backend.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';

void main() {
  late FakeCartBackend backend;
  late CartService cart;

  setUp(() {
    registerServices();
    backend = FakeCartBackend();
    cart = TestCart();
  });
  tearDown(() => locator.reset());

  group('CartServiceTest -', () {
    test('un cliente sin carrito ve uno vacío, no un error (CU-125)', () async {
      final r = await cart.refresh();
      expect(r.ok, isTrue);
      expect(cart.cart.isEmpty, isTrue);
      expect(cart.order, isNull);
      expect(backend.calls, ['GET cart']);
    });

    test('agregar manda POST /cart/items con X-Distributor y token (CU-122)',
        () async {
      await cart.add('g1', 2);
      final req = backend.log.single;
      expect(req.method, 'POST');
      expect(req.path, 'cart/items');
      expect(req.body, {'gasCylinderId': 'g1', 'quantity': 2});
      expect(req.headers['X-Distributor'], isNotNull);
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(cart.itemCount, 2);
      expect(cart.cart.total, 2000);
    });

    test('agregar el mismo tipo suma la cantidad, sin ítems repetidos',
        () async {
      await cart.add('g1', 1);
      await cart.add('g1', 2);
      expect(cart.cart.items, hasLength(1));
      expect(cart.quantityOf('g1'), 3);
    });

    test('el tope de cantidad del back se muestra y el carrito no cambia',
        () async {
      await cart.add('g1', 998);
      final r = await cart.add('g1', 5);
      expect(r.ok, isFalse);
      expect(r.status, 400);
      expect(r.message, contains('entero entre 1 y 999'));
      expect(cart.quantityOf('g1'), 998);
    });

    test('un tipo dado de baja se rechaza con el 404 del back', () async {
      backend.inactive.add('g2');
      final r = await cart.add('g2', 1);
      expect(r.ok, isFalse);
      expect(r.status, 404);
      expect(cart.cart.isEmpty, isTrue);
    });

    test('cambiar la cantidad es un PATCH al ítem (CU-123)', () async {
      await cart.add('g1', 1);
      final id = cart.cart.items.single.cartItemId;
      final r = await cart.setQuantity(id, 5);
      expect(r.ok, isTrue);
      final req = backend.log.last;
      expect(req.method, 'PATCH');
      expect(req.path, 'cart/items/$id');
      expect(req.body, {'quantity': 5});
      expect(cart.quantityOf('g1'), 5);
    });

    test('la cantidad cero la rechaza el back y se muestra (hay que quitar)',
        () async {
      await cart.add('g1', 2);
      final r = await cart.setQuantity(cart.cart.items.single.cartItemId, 0);
      expect(r.ok, isFalse);
      expect(r.message, contains('quitá el ítem'));
      expect(cart.quantityOf('g1'), 2);
    });

    test('quitar un ítem ajeno da 404 y deja el carrito (CU-124)', () async {
      await cart.add('g1', 1);
      final r = await cart.remove('no-es-mio');
      expect(r.ok, isFalse);
      expect(r.status, 404);
      expect(cart.quantityOf('g1'), 1);
    });

    test('quitar borra el ítem con DELETE (CU-124)', () async {
      await cart.add('g1', 1);
      await cart.add('g2', 1);
      await cart.remove(cart.cart.lineFor('g1')!.cartItemId);
      expect(backend.log.last.method, 'DELETE');
      expect(cart.cart.items.map((l) => l.gasCylinderId), ['g2']);
    });

    test('removeOne baja de a uno y con una sola unidad quita (stepper)',
        () async {
      await cart.add('g1', 2);
      await cart.removeOne('g1');
      expect(cart.quantityOf('g1'), 1);
      expect(backend.log.last.method, 'PATCH');
      await cart.removeOne('g1');
      expect(cart.cart.isEmpty, isTrue);
      expect(backend.log.last.method, 'DELETE');
      expect(backend.log.last.path, startsWith('cart/items/'));
    });

    test('vaciar es DELETE /cart (CU-126) y sin carrito no rompe', () async {
      await cart.add('g1', 1);
      await cart.add('g2', 1);
      await cart.clear();
      expect(backend.log.last.path, 'cart');
      expect(cart.cart.isEmpty, isTrue);
      expect((await cart.clear()).ok, isTrue);
    });

    test('el carrito aplica las promociones por cantidad que cargó el panel',
        () async {
      backend.promos['g1'] = [
        (quantity: 2, percent: 5),
        (quantity: 4, percent: 12),
      ];
      backend.setPrice('g1', 14900);
      await cart.add('g1', 1);
      expect(cart.cart.lineFor('g1')!.hasPromo, isFalse);
      expect(cart.cart.total, 14900);

      await cart.add('g1', 1);
      var line = cart.cart.lineFor('g1')!;
      expect(line.quantity, 2);
      expect(line.listUnitPrice, 14900);
      expect(line.currentUnitPrice, 14155);
      expect(line.discountPercentage, 5);
      expect(line.hasPromo, isTrue);
      expect(line.subtotal, 28310);
      expect(cart.cart.total, 28310);

      await cart.add('g1', 2);
      line = cart.cart.lineFor('g1')!;
      expect(line.currentUnitPrice, 13112);
      expect(line.discountPercentage, 12);
      expect(cart.cart.total, 52448);
      // La promoción no es un cambio de precio de lista.
      expect(line.priceChanged, isFalse);
      expect(cart.cart.hasPriceChanges, isFalse);
    });

    test('si el panel cambia la promoción, el próximo refresh ya la usa',
        () async {
      backend.promos['g1'] = [(quantity: 2, percent: 5)];
      await cart.add('g1', 2);
      expect(cart.cart.total, 1900);
      backend.promos['g1'] = [(quantity: 2, percent: 20)];
      await cart.refresh();
      expect(cart.cart.total, 1600);
      backend.promos['g1'] = [];
      await cart.refresh();
      expect(cart.cart.total, 2000);
      expect(cart.cart.lineFor('g1')!.hasPromo, isFalse);
    });

    test('el pedido armado desde el carrito lleva el precio con promoción',
        () async {
      backend.promos['g1'] = [(quantity: 2, percent: 10)];
      await cart.add('g1', 3);
      final item = cart.order!.items.single;
      expect(item.cylinder.price, 900);
      expect(item.subtotal, cart.cart.total);
    });

    test('un back viejo sin listUnitPrice no rompe: lista = vigente', () {
      final line = CartLine.fromJson({
        'cartItemId': 'i',
        'gasCylinderId': 'g',
        'currentUnitPrice': 500,
        'quantity': 2,
      })!;
      expect(line.listUnitPrice, 500);
      expect(line.hasPromo, isFalse);
    });

    test('muestra el cambio de precio, el ítem dado de baja y el stock',
        () async {
      await cart.add('g1', 2);
      await cart.add('g2', 1);
      backend
        ..setPrice('g1', 1200)
        ..inactive.add('g2')
        ..lowStock.add('g1');
      await cart.refresh();

      final g1 = cart.cart.lineFor('g1')!;
      expect(g1.priceChanged, isTrue);
      expect(g1.priceDifference, 200);
      expect(g1.savedUnitPrice, 1000);
      expect(g1.currentUnitPrice, 1200);
      expect(g1.hasEnoughStock, isFalse);
      final g2 = cart.cart.lineFor('g2')!;
      expect(g2.available, isFalse);
      expect(g2.subtotal, 0);
      expect(cart.cart.hasPriceChanges, isTrue);
      expect(cart.cart.hasUnavailableItems, isTrue);
      expect(cart.cart.hasStockWarnings, isTrue);
      expect(cart.cart.total, 2400);
    });

    test('sin conexión: mensaje claro y queda el último carrito del back',
        () async {
      await cart.add('g1', 1);
      backend.failNext = const FakeReply.networkError();
      final r = await cart.add('g1', 1);
      expect(r.ok, isFalse);
      expect(r.message, ApiErrorText.offline);
      expect(cart.quantityOf('g1'), 1);
    });

    test('un 5xx no se toma por éxito', () async {
      backend.failNext = const FakeReply(500, {'message': 'boom'});
      final r = await cart.add('g1', 1);
      expect(r.ok, isFalse);
      expect(r.message, ApiErrorText.server);
      expect(cart.cart.isEmpty, isTrue);
    });

    test('una respuesta ilegible no se toma por éxito', () async {
      backend.failNext = const FakeReply(200, {'foo': 'bar'});
      final r = await cart.add('g1', 1);
      expect(r.ok, isFalse);
      expect(cart.cart.isEmpty, isTrue);
    });

    test('sin sesión no llama al back', () async {
      final sinSesion = CartService(tokenReader: () async => null);
      final r = await sinSesion.add('g1', 1);
      expect(r.ok, isFalse);
      expect(r.message, ApiErrorText.sessionExpired);
      expect(backend.calls, isEmpty);
    });

    test('dos taps seguidos se hacen en orden y no se pisan', () async {
      final a = cart.add('g1', 1);
      final b = cart.add('g1', 1);
      await Future.wait([a, b]);
      expect(cart.quantityOf('g1'), 2);
      expect(backend.calls, ['POST cart/items', 'POST cart/items']);
    });

    test('el pedido del checkout sale del carrito con el precio vigente',
        () async {
      await cart.add('g1', 2);
      backend.setPrice('g1', 1200);
      await cart.refresh();
      cart.setAddress(addr('a1', 'Mitre 100'));
      final o = cart.order!;
      expect(o.items.single.quantity, 2);
      expect(o.items.single.cylinder.price, 1200);
      expect(o.total, 2400);
      expect(o.address?.addressId, 'a1');
    });

    test('repetir un pedido: vacía el carrito y agrega sus ítems', () async {
      await cart.add('g2', 4);
      final r = await cart.replaceWith([
        OrderItem(cylinder: cylinder(), quantity: 3),
      ]);
      expect(r.ok, isTrue);
      expect(cart.cart.items.map((l) => l.gasCylinderId), ['g1']);
      expect(cart.quantityOf('g1'), 3);
    });

    test('repetir se corta en el primer error', () async {
      await cart.add('g2', 1);
      backend.inactive.add('g1');
      final r = await cart.replaceWith([
        OrderItem(cylinder: cylinder(), quantity: 1),
        OrderItem(cylinder: cylinder(id: 'g2'), quantity: 1),
      ]);
      expect(r.ok, isFalse);
      expect(r.status, 404);
    });

    test('reset olvida carrito y dirección, y descarta respuestas viejas',
        () async {
      await cart.add('g1', 1);
      cart.setAddress(addr('a1', 'Mitre 100'));
      final pending = cart.add('g1', 1);
      cart.reset();
      await pending;
      expect(cart.cart.isEmpty, isTrue);
      expect(cart.address, isNull);
    });
  });
}
