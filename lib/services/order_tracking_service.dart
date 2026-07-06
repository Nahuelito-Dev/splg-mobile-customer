import 'dart:async';
import 'dart:developer';

import 'package:jennigas_customer/core/network/api_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class DriverLocationUpdate {
  const DriverLocationUpdate({
    required this.lat,
    required this.lng,
    required this.heading,
  });

  final double lat;
  final double lng;
  final double heading;
}

class OrderTrackingService {
  // Namespace 'customers' del backend (CustomersGateway). En el simulador iOS,
  // localhost apunta al host. Para el emulador Android usar 10.0.2.2.
  // TODO(config): centralizar esta base junto a la de ApiClient por entorno.
  static const String _socketBaseUrl = 'http://localhost:3000/customers';

  final _apiClient = ApiClient();
  io.Socket? _socket;

  /// Pedido que estamos siguiendo: filtramos los eventos que llegan al room del
  /// cliente para reaccionar solo a ESTE pedido.
  String? _trackedOrderId;

  final _driverLocationController =
      StreamController<DriverLocationUpdate>.broadcast();
  final _orderStatusController = StreamController<String>.broadcast();

  Stream<DriverLocationUpdate> get driverLocationUpdates =>
      _driverLocationController.stream;
  Stream<String> get orderStatusUpdates => _orderStatusController.stream;

  Future<Map<String, dynamic>?> fetchOrderById(
    String orderId,
    String token,
  ) async {
    try {
      final response = await _apiClient.get('orders/$orderId', token);
      if (response.statusCode != 200) {
        return null;
      }

      final data = _toMap(response.data);
      if (data == null) {
        return null;
      }

      return _extractOrderMap(data) ?? data;
    } catch (e) {
      log('e in fetchOrderById: ${e.toString()}');
      return null;
    }
  }

  void subscribeToOrder({
    required String orderId,
    required String customerId,
    String? token,
  }) {
    disconnect();
    _trackedOrderId = orderId;

    final builder = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(8)
        .setReconnectionDelay(1000);

    // El CustomersGateway valida el token de Firebase en el handshake (auth.token
    // o header Authorization). Mandamos ambos por compatibilidad.
    if (token != null && token.isNotEmpty) {
      builder.setAuth({'token': token});
      builder.setExtraHeaders({'Authorization': 'Bearer $token'});
    }

    _socket = io.io(_socketBaseUrl, builder.build());

    _socket?.onConnect((_) {
      // Nos unimos a nuestra sala de cliente: el backend emite ahí los eventos
      // de NUESTROS pedidos (ubicación del chofer + cambios de estado).
      _socket?.emit('customer:join', {'customerId': customerId});
    });

    // Ubicación del chofer en vivo (mientras el pedido está en camino).
    _socket?.on('order:driver-location', _onDriverLocationUpdate);

    // Cambios de estado del pedido → alertas al cliente.
    _socket?.on('order:accepted', _onOrderStatusUpdate);
    _socket?.on('order:on-the-way', _onOrderStatusUpdate);
    _socket?.on('order:delivered', _onOrderStatusUpdate);
    _socket?.on('order:cancelled', _onOrderStatusUpdate);

    _socket?.onError((e) => log('socket order tracking error: $e'));
    _socket?.onDisconnect((_) => log('socket order tracking disconnected'));

    _socket?.connect();
  }

  void disconnect() {
    _socket?.off('order:driver-location');
    _socket?.off('order:accepted');
    _socket?.off('order:on-the-way');
    _socket?.off('order:delivered');
    _socket?.off('order:cancelled');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _trackedOrderId = null;
  }

  void _onDriverLocationUpdate(dynamic payload) {
    final data = _toMap(payload);
    if (data == null) {
      return;
    }

    // Ignorar ubicaciones de otros pedidos del mismo cliente.
    if (!_isForTrackedOrder(data)) {
      return;
    }

    final lat = _toDouble(data['lat'] ?? data['latitude']);
    final lng = _toDouble(data['lng'] ?? data['longitude']);
    if (lat == null || lng == null) {
      return;
    }

    final heading = _toDouble(data['heading'] ?? data['bearing']) ?? 0;
    _driverLocationController.add(
      DriverLocationUpdate(lat: lat, lng: lng, heading: heading),
    );
  }

  void _onOrderStatusUpdate(dynamic payload) {
    final data = _toMap(payload);
    if (data == null) {
      return;
    }

    if (!_isForTrackedOrder(data)) {
      return;
    }

    final status = (data['status'] ?? data['orderStatus'] ?? data['state'])
        ?.toString();
    if (status != null && status.isNotEmpty) {
      _orderStatusController.add(status);
    }
  }

  /// True si el evento es del pedido que seguimos (o si no trae orderId, para no
  /// perder eventos legacy). El backend manda `orderId` en todos sus payloads.
  bool _isForTrackedOrder(Map<String, dynamic> data) {
    final incoming = (data['orderId'] ?? data['order_id'])?.toString();
    if (incoming == null || _trackedOrderId == null) {
      return true;
    }
    return incoming == _trackedOrderId;
  }

  Map<String, dynamic>? _extractOrderMap(Map<String, dynamic> raw) {
    if (_looksLikeOrder(raw)) {
      return raw;
    }

    for (final key in const ['order', 'data', 'result']) {
      final candidate = _toMap(raw[key]);
      if (candidate != null && _looksLikeOrder(candidate)) {
        return candidate;
      }

      final nested = candidate == null ? null : _toMap(candidate['order']);
      if (nested != null && _looksLikeOrder(nested)) {
        return nested;
      }
    }

    return null;
  }

  bool _looksLikeOrder(Map<String, dynamic> map) {
    return map.containsKey('order_id') ||
        map.containsKey('orderId') ||
        map.containsKey('id') ||
        map.containsKey('order_items') ||
        map.containsKey('items') ||
        map.containsKey('status');
  }

  Map<String, dynamic>? _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
