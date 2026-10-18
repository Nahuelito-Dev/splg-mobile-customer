/// Un ítem del carrito tal como lo devuelve el back (`GET /cart`).
class CartLine {
  const CartLine({
    required this.cartItemId,
    required this.gasCylinderId,
    required this.type,
    required this.quantity,
    required this.savedUnitPrice,
    required this.currentUnitPrice,
    required this.priceDifference,
    required this.subtotal,
    required this.available,
    required this.hasEnoughStock,
  });

  final String cartItemId;
  final String gasCylinderId;
  final String type;
  final int quantity;

  /// Lo que vio el cliente al agregarlo.
  final double savedUnitPrice;

  /// Lo que cuesta hoy en el catálogo: es lo que se cobra.
  final double currentUnitPrice;

  /// Vigente menos guardado.
  final double priceDifference;
  final double subtotal;

  /// false si el tipo se dio de baja después de agregarlo (no suma).
  final bool available;

  /// false si el stock vendible no alcanza para la cantidad (aviso nomás).
  final bool hasEnoughStock;

  bool get priceChanged => priceDifference.abs() > 0.004;

  static CartLine? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['cartItemId'];
    final cylinderId = json['gasCylinderId'];
    if (id is! String || cylinderId is! String) return null;
    return CartLine(
      cartItemId: id,
      gasCylinderId: cylinderId,
      type: (json['type'] ?? '').toString(),
      quantity: _int(json['quantity']),
      savedUnitPrice: _num(json['savedUnitPrice']),
      currentUnitPrice: _num(json['currentUnitPrice']),
      priceDifference: _num(json['priceDifference']),
      subtotal: _num(json['subtotal']),
      available: json['available'] != false,
      hasEnoughStock: json['hasEnoughStock'] != false,
    );
  }
}

/// El carrito del cliente en la distribuidora, como lo guarda el back.
class Cart {
  const Cart({
    this.cartId,
    this.items = const [],
    this.totalUnits = 0,
    this.total = 0,
    this.hasPriceChanges = false,
    this.hasUnavailableItems = false,
  });

  static const empty = Cart();

  final String? cartId;
  final List<CartLine> items;
  final int totalUnits;
  final double total;
  final bool hasPriceChanges;
  final bool hasUnavailableItems;

  bool get isEmpty => items.isEmpty;

  /// Unidades de todos los ítems (los no disponibles también).
  int get units => items.fold(0, (n, i) => n + i.quantity);

  bool get hasStockWarnings =>
      items.any((i) => i.available && !i.hasEnoughStock);

  CartLine? lineFor(String gasCylinderId) {
    for (final line in items) {
      if (line.gasCylinderId == gasCylinderId) return line;
    }
    return null;
  }

  int quantityOf(String gasCylinderId) => lineFor(gasCylinderId)?.quantity ?? 0;

  /// Null si el cuerpo no es un carrito legible.
  static Cart? fromJson(dynamic json) {
    if (json is! Map || json['items'] is! List) return null;
    final lines = <CartLine>[];
    for (final raw in json['items'] as List) {
      final line = CartLine.fromJson(raw);
      if (line == null) return null;
      lines.add(line);
    }
    return Cart(
      cartId: json['cartId'] as String?,
      items: lines,
      totalUnits: _int(json['totalUnits']),
      total: _num(json['total']),
      hasPriceChanges: json['hasPriceChanges'] == true,
      hasUnavailableItems: json['hasUnavailableItems'] == true,
    );
  }
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
