import 'package:splg_customer/services/cart_service.dart';

import 'fake_http.dart';

/// Un `/cart` de mentira que se comporta como el del back: guarda los ítems,
/// suma al agregar, valida cantidades y responde siempre el carrito completo.
class FakeCartBackend {
  FakeCartBackend({Map<String, ({String type, double price})>? catalog})
      : catalog = catalog ??
            {
              'g1': (type: 'Garrafa 10kg', price: 1000.0),
              'g2': (type: 'Garrafa 15kg', price: 1500.0),
            } {
    log = fakeHttp(_handle);
  }

  final Map<String, ({String type, double price})> catalog;
  late final List<RecordedRequest> log;

  /// cartItemId -> {gasCylinderId, quantity, savedUnitPrice}
  final Map<String, Map<String, Object>> _items = {};
  int _seq = 0;

  /// Tipos dados de baja después de agregarlos.
  final Set<String> inactive = {};

  /// Tipos sin stock suficiente.
  final Set<String> lowStock = {};

  /// La próxima llamada recibe esta respuesta en vez de la normal.
  FakeReply? failNext;

  /// Lo que se llamó, "MÉTODO ruta".
  List<String> get calls => [for (final r in log) '${r.method} ${r.path}'];

  /// Cambia el precio del catálogo (el guardado en el ítem queda como estaba).
  void setPrice(String gasCylinderId, double price) {
    final c = catalog[gasCylinderId]!;
    catalog[gasCylinderId] = (type: c.type, price: price);
  }

  Map<String, Object?> get _cart {
    final lines = <Map<String, Object?>>[];
    var total = 0.0;
    var units = 0;
    var changes = false;
    var unavailable = false;
    for (final e in _items.entries) {
      final id = e.value['gasCylinderId']! as String;
      final qty = e.value['quantity']! as int;
      final saved = e.value['savedUnitPrice']! as double;
      final c = catalog[id]!;
      final available = !inactive.contains(id);
      final subtotal = available ? c.price * qty : 0.0;
      total += subtotal;
      if (available) units += qty;
      if (c.price != saved) changes = true;
      if (!available) unavailable = true;
      lines.add({
        'cartItemId': e.key,
        'gasCylinderId': id,
        'type': c.type,
        'quantity': qty,
        'savedUnitPrice': saved,
        'currentUnitPrice': c.price,
        'priceDifference': c.price - saved,
        'subtotal': subtotal,
        'available': available,
        'hasEnoughStock': !lowStock.contains(id),
      });
    }
    return {
      'cartId': _items.isEmpty ? null : 'cart-1',
      'distributorId': 'd1',
      'items': lines,
      'totalUnits': units,
      'total': total,
      'hasPriceChanges': changes,
      'hasUnavailableItems': unavailable,
    };
  }

  FakeReply _handle(RecordedRequest r) {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return failure;
    }
    final path = r.path;
    final body = r.body is Map ? r.body! as Map : const {};
    if (r.method == 'GET' && path == 'cart') return FakeReply(200, _cart);
    if (r.method == 'DELETE' && path == 'cart') {
      _items.clear();
      return FakeReply(200, _cart);
    }
    if (r.method == 'POST' && path == 'cart/items') {
      final id = body['gasCylinderId'] as String;
      final qty = body['quantity'] as int;
      final type = catalog[id];
      if (type == null || inactive.contains(id)) {
        return const FakeReply(
            404, {'message': 'El tipo de garrafa no existe'});
      }
      final existing = _items.entries
          .where((e) => e.value['gasCylinderId'] == id)
          .firstOrNull;
      final total = qty + ((existing?.value['quantity'] as int?) ?? 0);
      if (qty < 1 || total > 999) {
        return const FakeReply(400,
            {'message': 'La cantidad tiene que ser un entero entre 1 y 999'});
      }
      if (existing != null) {
        existing.value['quantity'] = total;
        existing.value['savedUnitPrice'] = type.price;
      } else {
        _items['ci-${++_seq}'] = {
          'gasCylinderId': id,
          'quantity': qty,
          'savedUnitPrice': type.price,
        };
      }
      return FakeReply(201, _cart);
    }
    final item = RegExp(r'^cart/items/(.+)$').firstMatch(path);
    if (item != null) {
      final id = item.group(1)!;
      if (!_items.containsKey(id)) {
        return const FakeReply(
            404, {'message': 'El ítem no está en tu carrito'});
      }
      if (r.method == 'PATCH') {
        final qty = body['quantity'];
        if (qty is! int || qty < 1) {
          return const FakeReply(400, {
            'message': 'La cantidad tiene que ser mayor a cero: para dejarlo '
                'en cero, quitá el ítem'
          });
        }
        _items[id]!['quantity'] = qty;
        return FakeReply(200, _cart);
      }
      if (r.method == 'DELETE') {
        _items.remove(id);
        return FakeReply(200, _cart);
      }
    }
    return const FakeReply(500, {'message': 'ruta no simulada'});
  }
}

/// Un [CartService] real contra [FakeCartBackend], con sesión de prueba.
class TestCart extends CartService {
  TestCart() : super(tokenReader: () async => 'tok');
}
