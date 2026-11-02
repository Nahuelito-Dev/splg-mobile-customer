import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:splg_lib/network/api_error_text.dart';

/// Cómo terminó el intento de confirmar la entrega con el código del QR.
/// - `invalidCode`: el back lo rechazó con un 400 de negocio (código que no
///   coincide o pedido que ya no está en camino).
/// - `otherOrder`: el back reconoció el código como el de otro pedido en
///   camino del mismo cliente (`code: DELIVERY_CODE_OTRO_PEDIDO`).
/// - `malformedCode`: el back dijo que no tiene forma de código de entrega, o
///   sea que se leyó o se tipeó mal (`code: DELIVERY_CODE_FORMATO`).
/// - `blocked`: 409 `DELIVERY_CODE_BLOQUEADO`, se agotaron los intentos: el
///   chofer tiene que generar un código nuevo.
/// - `sessionExpired`: 401, la sesión dejó de valer.
/// - `networkError`: no hubo respuesta (sin conexión, timeout).
/// - `failed`: cualquier otro rechazo (403, 404, 5xx...).
enum ConfirmDeliveryResult {
  success,
  invalidCode,
  otherOrder,
  malformedCode,
  blocked,
  sessionExpired,
  networkError,
  failed,
}

/// Resultado de confirmar la entrega más el texto listo para mostrar (el
/// mensaje del back cuando es de negocio y está en castellano).
class ConfirmDeliveryOutcome {
  const ConfirmDeliveryOutcome(this.result, [this.message]);

  final ConfirmDeliveryResult result;
  final String? message;

  bool get isSuccess => result == ConfirmDeliveryResult.success;
}

class DriverLocationUpdate {
  const DriverLocationUpdate({
    required this.lat,
    required this.lng,
    required this.heading,
    this.at,
  });

  final double lat;
  final double lng;
  final double heading;

  /// Hora de la posición según el servidor (`at` de `order:driver-location`).
  final DateTime? at;
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
  io.Socket? _socket;

  /// Pedido que estamos siguiendo: filtramos los eventos que llegan al room del
  /// cliente para reaccionar solo a ESTE pedido.
  String? _trackedOrderId;

  final _driverLocationController =
      StreamController<DriverLocationUpdate>.broadcast();
  final _orderStatusController = StreamController<String>.broadcast();
  final _driverController = StreamController<DriverInfo>.broadcast();
  final _cancellationController = StreamController<String>.broadcast();
  final _cancelledByController = StreamController<String>.broadcast();
  final _arrivedController = StreamController<void>.broadcast();
  final _expressDegradedController = StreamController<void>.broadcast();
  final _orderChangedController = StreamController<void>.broadcast();

  /// Si el back cortó la conexión por el token vencido (`server:session-expired`):
  /// socket.io no reconecta solo cuando corta el servidor.
  bool _reconnectOnServerCut = false;

  Stream<DriverLocationUpdate> get driverLocationUpdates =>
      _driverLocationController.stream;
  Stream<String> get orderStatusUpdates => _orderStatusController.stream;
  Stream<DriverInfo> get driverUpdates => _driverController.stream;

  /// Motivo de una cancelación (`reason` de `order:cancelled`); sale antes que
  /// el cambio de estado.
  Stream<String> get cancellationReasons => _cancellationController.stream;

  /// Quién canceló (`cancelledBy` de `order:cancelled`: customer, admin,
  /// driver o system).
  Stream<String> get cancelledBys => _cancelledByController.stream;

  /// El repartidor avisó que llegó (`order:arrived`).
  Stream<void> get arrivedUpdates => _arrivedController.stream;

  /// Un pedido express pasó al reparto común (`order:express-degraded`).
  Stream<void> get expressDegradedUpdates => _expressDegradedController.stream;

  /// El pedido cambió sin cambiar de estado: lo modificó el cliente
  /// (`order:updated`), se aprobó el pago (`order:payment-approved`) o se
  /// reintegró (`order:payment-refunded`). Hay que volver a leerlo.
  Stream<void> get orderChanges => _orderChangedController.stream;

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

  /// `GET /orders/:id`. Null ante red o 5xx (se puede reintentar); lanza
  /// [orderGoneFailure] ante 404/410: el pedido ya no existe para este usuario
  /// y volver a pedirlo no cambia nada.
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
      if (isOrderGone(e)) throw orderGoneFailure;
      log('e in fetchOrderById: ${e.toString()}');
      return null;
    }
  }

  /// Claves de idempotencia de la confirmación, por pedido y código leído.
  final _deliveryKeys = IdempotencyKeys();

  /// POST /orders/:orderId/confirm-delivery con el codigo leido del QR del
  /// chofer. Idempotente via header `Idempotency-Key`: el mismo pedido y
  /// código reusan la clave mientras no haya respuesta definitiva (sin
  /// respuesta, 5xx, 429, 409 "en curso" o 422), asi el reintento no
  /// reprocesa la entrega. Con exito o un rechazo de negocio la clave se
  /// descarta. El back responde 201 al confirmar: cualquier 2xx es exito.
  Future<ConfirmDeliveryOutcome> confirmDelivery(
    String orderId,
    String code,
    String token,
  ) async {
    final intention = '$orderId|$code';
    try {
      final response = await _apiClient.post(
        'orders/$orderId/confirm-delivery',
        {'code': code},
        token,
        {'Idempotency-Key': _deliveryKeys.keyFor(intention)},
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        _deliveryKeys.settle(intention, keep: false);
        return const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success);
      }
      _deliveryKeys.settle(intention,
          keep: keepIdempotencyKey(status, response.data));
      return ConfirmDeliveryOutcome(
        ConfirmDeliveryResult.failed,
        ApiErrorText.of(status, response.data),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      log('e in confirmDelivery: ${e.type} $status');
      _deliveryKeys.settle(intention, keep: keepIdempotencyKey(status, data));
      if (status == null) {
        return const ConfirmDeliveryOutcome(
          ConfirmDeliveryResult.networkError,
          ApiErrorText.offline,
        );
      }
      if (status == 400) {
        final reason = data is Map ? data['code'] : null;
        if (reason == 'DELIVERY_CODE_OTRO_PEDIDO') {
          return const ConfirmDeliveryOutcome(
            ConfirmDeliveryResult.otherOrder,
            otherOrderText,
          );
        }
        if (reason == 'DELIVERY_CODE_FORMATO') {
          return const ConfirmDeliveryOutcome(
            ConfirmDeliveryResult.malformedCode,
            malformedCodeText,
          );
        }
        return ConfirmDeliveryOutcome(
          ConfirmDeliveryResult.invalidCode,
          ApiErrorText.businessMessage(status, data) ?? _invalidCodeText,
        );
      }
      if (status == 409 &&
          data is Map &&
          data['code'] == 'DELIVERY_CODE_BLOQUEADO') {
        return const ConfirmDeliveryOutcome(
          ConfirmDeliveryResult.blocked,
          blockedText,
        );
      }
      if (isIdempotencyConflict(status, data)) {
        return const ConfirmDeliveryOutcome(
          ConfirmDeliveryResult.failed,
          'Ya recibimos tu confirmación. Revisá el estado del pedido.',
        );
      }
      return ConfirmDeliveryOutcome(
        status == 401
            ? ConfirmDeliveryResult.sessionExpired
            : ConfirmDeliveryResult.failed,
        ApiErrorText.of(status, data),
      );
    } catch (e) {
      log('e in confirmDelivery: ${e.runtimeType}');
      _deliveryKeys.settle(intention, keep: true);
      return const ConfirmDeliveryOutcome(
        ConfirmDeliveryResult.failed,
        ApiErrorText.generic,
      );
    }
  }

  static const otherOrderText =
      'Ese código es de otro de tus pedidos en camino. Escaneá el QR del repartidor que trae este pedido.';
  static const blockedText =
      'Demasiados intentos: pedile al chofer un código nuevo.';
  static const malformedCodeText =
      'No pudimos leer bien el código. Acercá el celular al QR y probá de nuevo.';

  static const _invalidCodeText =
      'El código no es válido o el pedido ya no está en camino.';

  /// Auth del handshake de Socket.IO: una función que pide el token en cada
  /// conexión (también en las reconexiones). El token de Firebase vence en una
  /// hora; uno tomado una sola vez al abrir el seguimiento deja de valer y el
  /// back rechaza la reconexión.
  static void Function(void Function(Map<String, dynamic>) done) authFor(
    Future<String?> Function() tokenProvider,
  ) {
    return (done) async {
      String? token;
      try {
        token = await tokenProvider();
      } catch (e) {
        log('socket order tracking: no se pudo leer el token: ${e.runtimeType}');
      }
      done(token == null || token.isEmpty
          ? <String, dynamic>{}
          : {'token': token});
    };
  }

  void subscribeToOrder({
    required String orderId,
    required String customerId,
    Future<String?> Function()? tokenProvider,
  }) {
    disconnect();
    _trackedOrderId = orderId;

    final builder = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        // Sin tope de intentos: el seguimiento dura lo que dura la entrega.
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(10000);

    _socket = io.io(AppConfig.customersNamespace, builder.build());

    // El CustomersGateway valida el token de Firebase en el handshake
    // (`auth.token`); se pide fresco en cada conexión.
    if (tokenProvider != null) {
      _socket?.auth = authFor(tokenProvider);
    }

    _socket?.onConnect((_) {
      // Nos unimos a nuestra sala de cliente: el backend emite ahí los eventos
      // de NUESTROS pedidos (ubicación del chofer + cambios de estado).
      _socket?.emit('customer:join', {'customerId': customerId});
    });

    // Ubicación del chofer en vivo (mientras el pedido está en camino).
    _socket?.on('order:driver-location', onDriverLocationUpdate);

    // Cambios de estado del pedido → alertas al cliente.
    _socket?.on('order:accepted', onOrderStatusUpdate);
    _socket?.on('order:on-the-way', onOrderStatusUpdate);
    _socket?.on('order:delivered', onOrderStatusUpdate);
    _socket?.on('order:cancelled', onOrderStatusUpdate);
    // El chofer liberó el pedido: vuelve a buscarse repartidor (`pending`).
    _socket?.on('order:searching-driver', onOrderStatusUpdate);
    _socket?.on('order:arrived', onArrived);
    _socket?.on('order:express-degraded', onExpressDegraded);
    _socket?.on('order:updated', onOrderChanged);
    _socket?.on('order:payment-approved', onOrderChanged);
    _socket?.on('order:payment-refunded', onOrderChanged);
    _socket?.on('server:session-expired', onSessionExpired);
    _socket?.on('server:access-revoked', onAccessRevoked);

    _socket?.onConnectError((e) => log('socket order tracking connect error'));
    _socket?.onError((e) => log('socket order tracking error: $e'));
    _socket?.onDisconnect((reason) {
      log('socket order tracking disconnected ($reason)');
      // Vuelve con un token nuevo: `auth` lo pide en cada conexión.
      if (takeReconnectAfterDisconnect(reason)) _socket?.connect();
    });

    _socket?.connect();
  }

  void disconnect() {
    _socket?.off('order:driver-location');
    _socket?.off('order:accepted');
    _socket?.off('order:on-the-way');
    _socket?.off('order:delivered');
    _socket?.off('order:cancelled');
    _socket?.off('order:searching-driver');
    _socket?.off('order:arrived');
    _socket?.off('order:express-degraded');
    _socket?.off('order:updated');
    _socket?.off('order:payment-approved');
    _socket?.off('order:payment-refunded');
    _socket?.off('server:session-expired');
    _socket?.off('server:access-revoked');
    _reconnectOnServerCut = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _trackedOrderId = null;
  }

  @visibleForTesting
  void onDriverLocationUpdate(dynamic payload) {
    final data = _toMap(payload);
    if (data == null) {
      return;
    }

    // Ignorar ubicaciones de otros pedidos del mismo cliente.
    if (!_isForTrackedOrder(data)) {
      return;
    }

    final lat = _toDouble(data['lat']);
    final lng = _toDouble(data['lng']);
    if (lat == null || lng == null) {
      return;
    }

    final heading = _toDouble(data['heading']) ?? 0;
    _driverLocationController.add(
      DriverLocationUpdate(
        lat: lat,
        lng: lng,
        heading: heading,
        at: DateTime.tryParse(data['at']?.toString() ?? ''),
      ),
    );
  }

  @visibleForTesting
  void onExpressDegraded(dynamic payload) {
    final data = _toMap(payload);
    if (data == null || !_isForTrackedOrder(data)) return;
    _expressDegradedController.add(null);
  }

  @visibleForTesting
  void onOrderChanged(dynamic payload) {
    final data = _toMap(payload);
    if (data == null || !_isForTrackedOrder(data)) return;
    _orderChangedController.add(null);
  }

  @visibleForTesting
  void onSessionExpired(dynamic _) => _reconnectOnServerCut = true;

  /// Bloqueo o baja de la cuenta: no se vuelve a conectar.
  @visibleForTesting
  void onAccessRevoked(dynamic _) => _reconnectOnServerCut = false;

  /// Si hay que reconectar a mano tras este corte. Sólo una vez por aviso: un
  /// handshake rechazado después no reintenta en bucle.
  @visibleForTesting
  bool takeReconnectAfterDisconnect(dynamic reason) {
    final again = reason == 'io server disconnect' && _reconnectOnServerCut;
    _reconnectOnServerCut = false;
    return again;
  }

  @visibleForTesting
  void onArrived(dynamic payload) {
    final data = _toMap(payload);
    if (data == null || !_isForTrackedOrder(data)) return;
    _arrivedController.add(null);
  }

  @visibleForTesting
  void onOrderStatusUpdate(dynamic payload) {
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

    final reason = data['reason']?.toString().trim();
    if (reason != null && reason.isNotEmpty) {
      _cancellationController.add(reason);
    }

    final cancelledBy = data['cancelledBy']?.toString().trim();
    if (cancelledBy != null && cancelledBy.isNotEmpty) {
      _cancelledByController.add(cancelledBy);
    }

    final status = data['status']?.toString();
    if (status != null && status.isNotEmpty) {
      _orderStatusController.add(status);
    }
  }

  /// True si el evento es del pedido que seguimos (o si no trae orderId, para no
  /// perder eventos legacy). El backend manda `orderId` en todos sus payloads.
  bool _isForTrackedOrder(Map<String, dynamic> data) {
    final incoming = data['orderId']?.toString();
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
