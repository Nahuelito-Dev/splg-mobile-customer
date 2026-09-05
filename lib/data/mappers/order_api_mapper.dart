import 'package:splg_lib/domain/order.dart';

class OrderApiMapper {
  static Order? parseOrder(dynamic raw) {
    final rawMap = _extractOrderMap(raw);
    if (rawMap == null) return null;

    try {
      return Order.fromJson(_normalizeOrder(rawMap));
    } catch (_) {
      return null;
    }
  }

  static List<Order> parseOrders(dynamic raw) {
    final maps = _extractOrderMaps(raw);
    final orders = <Order>[];

    for (final map in maps) {
      try {
        orders.add(Order.fromJson(_normalizeOrder(map)));
      } catch (_) {
        continue;
      }
    }

    return orders;
  }

  static Map<String, dynamic>? _extractOrderMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (_looksLikeOrder(raw)) return raw;

      for (final key in const ['order', 'data', 'result']) {
        final candidate = raw[key];
        if (candidate is Map<String, dynamic> && _looksLikeOrder(candidate)) {
          return candidate;
        }
      }

      final data = raw['data'];
      if (data is Map<String, dynamic>) {
        for (final key in const ['order', 'result']) {
          final candidate = data[key];
          if (candidate is Map<String, dynamic> && _looksLikeOrder(candidate)) {
            return candidate;
          }
        }
      }
    }

    return null;
  }

  static List<Map<String, dynamic>> _extractOrderMaps(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    if (raw is Map<String, dynamic>) {
      for (final key in const ['orders', 'history', 'results']) {
        final candidate = raw[key];
        if (candidate is List) {
          return candidate.whereType<Map<String, dynamic>>().toList();
        }
      }

      final data = raw['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }

      if (data is Map<String, dynamic>) {
        for (final key in const ['orders', 'history', 'results']) {
          final candidate = data[key];
          if (candidate is List) {
            return candidate.whereType<Map<String, dynamic>>().toList();
          }
        }
      }
    }

    return const [];
  }

  static bool _looksLikeOrder(Map<String, dynamic> map) {
    return map.containsKey('order_id') ||
        map.containsKey('id') ||
        map.containsKey('orderItems') ||
        map.containsKey('order_items') ||
        map.containsKey('items');
  }

  static Map<String, dynamic> _normalizeOrder(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);

    normalized['order_id'] = _pick(raw, ['order_id', 'orderId', 'id']) ?? '';
    normalized['total_amount'] =
        _asNum(_pick(raw, ['total_amount', 'totalAmount', 'total'])) ?? 0;
    normalized['payment_method'] = _normalizePaymentMethod(
      _pick(raw, ['payment_method', 'paymentMethod'])?.toString(),
    );
    normalized['status'] = _normalizeStatus(
      _pick(raw, ['status'])?.toString(),
    );

    final createdAt = _pick(raw, ['created_at', 'createdAt']);
    normalized['created_at'] = createdAt ?? DateTime.now().toIso8601String();

    normalized['delivery_address'] = _normalizeAddress(
      _pick(raw, ['delivery_address', 'deliveryAddress', 'address']),
    );
    normalized['order_items'] = _normalizeItems(
      _pick(raw, ['order_items', 'orderItems', 'items']),
    );

    normalized['requested_delivery_date'] =
        _pick(raw, ['requested_delivery_date', 'requestedDeliveryDate']);
    normalized['actual_delivery_date'] =
        _pick(raw, ['actual_delivery_date', 'actualDeliveryDate']);
    normalized['delivery_window_start'] =
        _pick(raw, ['delivery_window_start', 'deliveryWindowStart']);
    normalized['delivery_window_end'] =
        _pick(raw, ['delivery_window_end', 'deliveryWindowEnd']);
    normalized['customer_notes'] =
        _pick(raw, ['customer_notes', 'customerNotes']);
    normalized['delivery_notes'] =
        _pick(raw, ['delivery_notes', 'deliveryNotes']);
    normalized['delivery_id'] = _pick(raw, ['delivery_id', 'deliveryId']);
    normalized['delivery_name'] = _pick(raw, ['delivery_name', 'deliveryName']);

    return normalized;
  }

  static Map<String, dynamic> _normalizeAddress(dynamic value) {
    final map = value is Map<String, dynamic>
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};

    return {
      'address_id':
          _pick(map, ['address_id', 'addressId', 'id'])?.toString() ?? '',
      'street': _pick(map, ['street', 'streetName'])?.toString() ?? '',
      'city': _pick(map, ['city'])?.toString(),
      'latitude': _pick(map, ['latitude', 'lat'])?.toString(),
      'longitude': _pick(map, ['longitude', 'lng'])?.toString(),
      'postalCode': _pick(map, ['postalCode', 'postal_code'])?.toString(),
      'formattedAddress':
          _pick(map, ['formattedAddress', 'formatted_address'])?.toString(),
      'additionalInstructions': _pick(
        map,
        ['additionalInstructions', 'additional_instructions'],
      )?.toString(),
      'isDefault': _pick(map, ['isDefault', 'primary']) ?? true,
    };
  }

  static List<Map<String, dynamic>> _normalizeItems(dynamic value) {
    if (value is! List) return const [];

    return value.whereType<Map<String, dynamic>>().map((item) {
      final cylinderRaw = _pick(item, ['gas_cylinder', 'gasCylinder']);
      final cylinderMap = cylinderRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(cylinderRaw)
          : <String, dynamic>{};

      final unitPrice =
          _asNum(_pick(item, ['unitPrice', 'unit_price', 'price'])) ??
              _asNum(_pick(cylinderMap, ['price'])) ??
              0;

      return {
        'quantity': _asInt(_pick(item, ['quantity'])) ?? 0,
        'gas_cylinder': {
          'gas_cylinder_id':
              _pick(cylinderMap, ['gas_cylinder_id', 'gasCylinderId', 'id']) ??
                  _pick(item, ['gasCylinderId', 'gas_cylinder_id']) ??
                  '',
          'type': _pick(cylinderMap, ['type'])?.toString() ?? '',
          'weight': _pick(cylinderMap, ['weight'])?.toString() ?? '',
          'price': unitPrice,
          'isActive': _pick(cylinderMap, ['isActive', 'active']) ?? true,
          'description': _pick(
                cylinderMap,
                ['description', 'name'],
              )?.toString() ??
              '',
          'promotions': _pick(cylinderMap, ['promotions', 'discounts']) ?? [],
        },
      };
    }).toList();
  }

  static dynamic _pick(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) return map[key];
    }
    return null;
  }

  static String _normalizeStatus(String? status) {
    if (status == null || status.isEmpty) return 'pending';
    final normalized = status.trim().toLowerCase();
    if (normalized == 'on_the_way' ||
        normalized == 'in_progress' ||
        normalized == 'in-progress' ||
        normalized == 'in_route') {
      return 'out_for_delivery';
    }
    if (normalized == 'assigned') {
      return 'accepted';
    }
    return normalized;
  }

  static String _normalizePaymentMethod(String? method) {
    if (method == null || method.isEmpty) return 'cash';
    if (method == 'transfer') return 'online';
    return method;
  }

  /// Serializa un [PaymentMethod] al string que espera el backend al crear
  /// o modificar un pedido (`@IsEnum(['cash', 'mercadopago', 'transfer'])`).
  static String serializePaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.online:
        return 'transfer';
      case PaymentMethod.mercadoPago:
        return 'mercadopago';
    }
  }

  /// Extrae el `paymentUrl` (init_point de Checkout Pro) que el backend
  /// devuelve en la respuesta de creación cuando `paymentMethod` es
  /// `mercadopago`. Para el resto de los métodos de pago viene ausente/null.
  static String? extractPaymentUrl(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final direct = _pick(raw, ['paymentUrl', 'payment_url']);
    if (direct is String && direct.isNotEmpty) return direct;

    for (final key in const ['data', 'order', 'result']) {
      final nested = raw[key];
      if (nested is Map<String, dynamic>) {
        final value = _pick(nested, ['paymentUrl', 'payment_url']);
        if (value is String && value.isNotEmpty) return value;
      }
    }

    return null;
  }

  static double? _asNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
