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
  static const String _socketBaseUrl = 'https://jennygas-app-backend.onrender.com';

  final _apiClient = ApiClient();
  io.Socket? _socket;

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
    String? token,
  }) {
    disconnect();

    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(8)
        .setReconnectionDelay(1000)
        .build();

    if (token != null && token.isNotEmpty) {
      options['extraHeaders'] = {'Authorization': 'Bearer $token'};
    }

    _socket = io.io(_socketBaseUrl, options);

    _socket?.onConnect((_) {
      final room = 'order_$orderId';
      _socket?.emit('subscribe_order', {'room': room, 'orderId': orderId});
      _socket?.emit('subscribe_order', room);
    });

    _socket?.on('driver_location_update', _onDriverLocationUpdate);
    _socket?.on('order_status_update', _onOrderStatusUpdate);
    _socket?.on('order_update', _onOrderStatusUpdate);
    _socket?.onError((e) => log('socket order tracking error: $e'));
    _socket?.onDisconnect((_) => log('socket order tracking disconnected'));

    _socket?.connect();
  }

  void disconnect() {
    _socket?.off('driver_location_update');
    _socket?.off('order_status_update');
    _socket?.off('order_update');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _onDriverLocationUpdate(dynamic payload) {
    final data = _toMap(payload);
    if (data == null) {
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

    final status = (data['status'] ?? data['orderStatus'] ?? data['state'])
        ?.toString();
    if (status != null && status.isNotEmpty) {
      _orderStatusController.add(status);
    }
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
