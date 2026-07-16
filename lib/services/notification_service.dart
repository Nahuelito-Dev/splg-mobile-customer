import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/data/datasource/notification_remote_datasource.dart';
import 'package:jennigas_customer/services/customer_service.dart';

/// Notificaciones push (FCM). Pide permiso, obtiene el token del device y lo
/// registra contra el backend (`POST /notifications/token`), que lo usa para
/// avisar cambios de estado del pedido (`sendOrderConfirmation` /
/// `sendOrderStatusUpdate` en `notifications.service.ts`). También muestra un
/// aviso local cuando llega un push con la app en foreground, porque FCM no
/// lo muestra solo en ese caso (solo en background/terminated).
///
/// iOS: hasta que se suba el APNs Auth Key (.p8) a Firebase Console → Cloud
/// Messaging, `getToken()` en iOS puede devolver null o tirar error. Todo el
/// flujo está en try/catch para no romper el resto de la app mientras tanto;
/// Android funciona ya con el `google-services.json` actual.
class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _datasource = NotificationRemoteDatasource();
  final _customerService = locator<CustomerService>();

  bool _listenersAttached = false;

  /// Pide permiso, registra el token FCM actual (si hay sesión) y deja
  /// enganchados los listeners de refresh de token y mensajes en foreground.
  /// Idempotente: se puede llamar en cada apertura de la app y en cada login
  /// sin duplicar listeners.
  Future<void> initialize() async {
    try {
      await _requestPermission();
      await _initLocalNotifications();
      _attachListenersOnce();
      await registerCurrentToken();
    } catch (e) {
      log('NotificationService.initialize error: $e');
    }
  }

  /// Obtiene el token FCM actual y lo registra contra el backend si hay
  /// sesión iniciada. Se expone aparte de [initialize] para poder re-llamarlo
  /// justo después de un login/registro exitoso (antes puede no haber
  /// customer logueado todavía).
  Future<void> registerCurrentToken() async {
    if (!_customerService.isUserLoggedIn) return;

    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;
      await _registerToken(fcmToken);
    } catch (e) {
      log('NotificationService.registerCurrentToken error: $e');
    }
  }

  /// Token FCM crudo del device, para adjuntarlo como `notificationToken` al
  /// crear un pedido. Devuelve `null` si no se pudo obtener (p.ej. iOS sin
  /// APNs key configurada todavía).
  Future<String?> get currentToken async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      log('NotificationService.currentToken error: $e');
      return null;
    }
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      log('NotificationService.requestPermission error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    try {
      await _localNotifications.initialize(settings: settings);
    } catch (e) {
      log('NotificationService.initLocalNotifications error: $e');
    }
  }

  void _attachListenersOnce() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _messaging.onTokenRefresh.listen(
      (newToken) => _registerToken(newToken),
      onError: (e) => log('NotificationService.onTokenRefresh error: $e'),
    );
  }

  Future<void> _registerToken(String fcmToken) async {
    if (!_customerService.isUserLoggedIn) return;
    final authToken = await _customerService.token;
    if (authToken == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await _datasource.registerToken(
        userId: _customerService.customer.customerId,
        fcmToken: fcmToken,
        platform: platform,
        authToken: authToken,
      );
    } catch (e) {
      log('NotificationService._registerToken error: $e');
    }
  }

  /// FCM entrega el `notification` payload pero no lo muestra solo cuando la
  /// app está en foreground (a diferencia de background/terminated), así que
  /// lo mostramos como notificación local para que el cliente lo vea igual.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'orders_channel',
      'Actualizaciones de pedidos',
      channelDescription: 'Avisos de cambios de estado de tus pedidos',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }
}
