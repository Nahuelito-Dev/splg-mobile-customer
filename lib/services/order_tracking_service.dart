import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

/// Resultado de intentar confirmar la entrega con el codigo leido del QR del
/// chofer. `invalidCode` cubre tanto codigo incorrecto como pedido que ya no
/// esta `on_the_way` (el backend devuelve 400 en ambos casos).
enum ConfirmDeliveryResult { success, invalidCode, networkError }

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

/// Chofer asignado tal como lo manda el back en `order:accepted` y
/// `order:on-the-way`. `photoUrl` es una URL firmada que vence en minutos.
class DriverInfo {
  const DriverInfo({this.name, this.phone, this.photoUrl});

  final String? name;
  final String? phone;
  final String? photoUrl;
}

/// Resultado de `GET /orders/:id/driver-photo?modo=url`.
/// [url] nulo: el chofer no tiene foto o el back no la da (409/404).
/// [failed]: no se pudo consultar (red, 5xx); no dice nada sobre la foto.
class DriverPhotoLookup {
  const DriverPhotoLookup({this.url, this.expiresAt, this.failed = false});

  final String? url;
  final DateTime? expiresAt;
  final bool failed;
}

class OrderTrackingService {
  final _apiClient = ApiClient();
  final _uuid = const Uuid();
  io.Socket? _socket;

  /// Pedido que estamos siguiendo: filtramos los eventos que llegan al room del
  /// cliente para reaccionar solo a ESTE pedido.
  String? _trackedOrderId;

  final _driverLocationController =
      StreamController<DriverLocationUpdate>.broadcast();
  final _orderStatusController = StreamController<String>.broadcast();
  final _driverController = StreamController<DriverInfo>.broadcast();

  Stream<DriverLocationUpdate> get driverLocationUpdates =>
      _driverLocationController.stream;
  Stream<String> get orderStatusUpdates => _orderStatusController.stream;
  Stream<DriverInfo> get driverUpdates => _driverController.stream;

  /// Renueva la URL firmada de la foto del chofer. 409 (pedido fuera de
  /// aceptado/en camino) y 404 no son error: significan "sin foto".
  Future<DriverPhotoLookup> fetchDriverPhoto(
    String orderId,
    String token,
  ) async {
    try {
      final response = await _apiClient.get(
        'orders/$orderId/driver-photo?modo=url',
        token,
      );
      final data = _toMap(response.data);
      final url = data?['url']?.toString();
      if (data == null || url == null || url.isEmpty) {
        return const DriverPhotoLookup();
      }
      return DriverPhotoLookup(
        url: url,
        expiresAt: DateTime.tryParse(data['expiresAt']?.toString() ?? ''),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409 || code == 404) {
        return const DriverPhotoLookup();
      }
      log('e in fetchDriverPhoto: ${e.type}');
      return const DriverPhotoLookup(failed: true);
    } catch (e) {
      log('e in fetchDriverPhoto: ${e.runtimeType}');
      return const DriverPhotoLookup(failed: true);
    }
  }

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

  /// POST /orders/:orderId/confirm-delivery con el codigo leido del QR del
  /// chofer. Idempotente via header `Idempotency-Key` (un uuid v4 por
  /// intento del usuario, asi un reintento de red no reprocesa la entrega).
  Future<ConfirmDeliveryResult> confirmDelivery(
    String orderId,
    String code,
    String token,
  ) async {
    try {
      final response = await _apiClient.post(
        'orders/$orderId/confirm-delivery',
        {'code': code},
        token,
        {'Idempotency-Key': _uuid.v4()},
      );

      if (response.statusCode == 200) {
        return ConfirmDeliveryResult.success;
      }

      return ConfirmDeliveryResult.invalidCode;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return ConfirmDeliveryResult.invalidCode;
      }
      log('e in confirmDelivery: ${e.toString()}');
      return ConfirmDeliveryResult.networkError;
    } catch (e) {
      log('e in confirmDelivery: ${e.toString()}');
      return ConfirmDeliveryResult.networkError;
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

    _socket = io.io(AppConfig.customersNamespace, builder.build());

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

    final driver = _toMap(data['driver']);
    if (driver != null) {
      String? text(dynamic v) {
        final t = v?.toString().trim();
        return (t == null || t.isEmpty) ? null : t;
      }

      _driverController.add(DriverInfo(
        name: text(driver['name']),
        phone: text(driver['phone']),
        photoUrl: text(driver['photoUrl']),
      ));
    }

    final status =
        (data['status'] ?? data['orderStatus'] ?? data['state'])?.toString();
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
