import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';

/// Aviso de que el cliente tiene una invitación de recompra nueva
/// (`repurchase:invitation`): la app vuelve a leer sus invitaciones.
class RepurchaseInvitationEvent {
  const RepurchaseInvitationEvent(this.invitationId);

  final String? invitationId;
}

/// La invitación se cerró sin que el cliente la contestara
/// (`repurchase:invitation-closed`): venció o compró por su cuenta.
class RepurchaseClosedEvent {
  const RepurchaseClosedEvent(this.invitationId, this.reason);

  final String? invitationId;
  final String? reason;
}

/// Hay algo nuevo de sus envases sin devolver (`cylinder-recovery:notice`).
class RecoveryNoticeEvent {
  const RecoveryNoticeEvent({this.caseId, this.kind, this.title, this.body});

  final String? caseId;

  /// `reminder`, `deposit_warning` o `pickup_offer`.
  final String? kind;
  final String? title;
  final String? body;
}

/// Avisos en vivo al cliente fuera del seguimiento de un pedido: recompra (M3)
/// y recupero de envases (M5). Una conexión al namespace `/customers` mientras
/// el Inicio está a la vista. Todo lo que llega es sólo un aviso para volver a
/// leer: la fuente de verdad es siempre la API.
class CustomerEventsService {
  io.Socket? _socket;
  bool _reconnectOnServerCut = false;

  final _invitationController =
      StreamController<RepurchaseInvitationEvent>.broadcast();
  final _closedController = StreamController<RepurchaseClosedEvent>.broadcast();
  final _recoveryController =
      StreamController<RecoveryNoticeEvent>.broadcast();

  Stream<RepurchaseInvitationEvent> get repurchaseInvitations =>
      _invitationController.stream;
  Stream<RepurchaseClosedEvent> get repurchaseClosed =>
      _closedController.stream;
  Stream<RecoveryNoticeEvent> get recoveryNotices => _recoveryController.stream;

  bool get isConnected => _socket != null;

  /// Abre la conexión y se une a la sala del cliente. Idempotente.
  void connect() {
    if (_socket != null) return;
    final customers = locator<CustomerService>();
    if (!customers.isUserLoggedIn) return;
    final customerId = customers.customer.customerId;

    final socket = io.io(
      AppConfig.customersNamespace,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .build(),
    );
    _socket = socket;
    // El token se pide en cada (re)conexión: el de Firebase vence en una hora.
    socket.auth = OrderTrackingService.authFor(() => customers.token);
    socket.onConnect(
        (_) => socket.emit('customer:join', {'customerId': customerId}));
    socket.on('repurchase:invitation', onInvitation);
    socket.on('repurchase:invitation-closed', onInvitationClosed);
    socket.on('cylinder-recovery:notice', onRecoveryNotice);
    socket.on('server:session-expired', (_) => _reconnectOnServerCut = true);
    socket.on('server:access-revoked', (_) => _reconnectOnServerCut = false);
    socket.onConnectError((e) => log('socket customer events connect error'));
    socket.onDisconnect((reason) {
      final again = reason == 'io server disconnect' && _reconnectOnServerCut;
      _reconnectOnServerCut = false;
      if (again) socket.connect();
    });
    socket.connect();
  }

  void disconnect() {
    final socket = _socket;
    if (socket == null) return;
    socket
      ..off('repurchase:invitation')
      ..off('repurchase:invitation-closed')
      ..off('cylinder-recovery:notice')
      ..off('server:session-expired')
      ..off('server:access-revoked')
      ..disconnect()
      ..dispose();
    _socket = null;
    _reconnectOnServerCut = false;
  }

  @visibleForTesting
  void onInvitation(dynamic payload) {
    final data = _toMap(payload);
    _invitationController
        .add(RepurchaseInvitationEvent(data?['invitationId']?.toString()));
  }

  @visibleForTesting
  void onInvitationClosed(dynamic payload) {
    final data = _toMap(payload);
    _closedController.add(RepurchaseClosedEvent(
        data?['invitationId']?.toString(), data?['reason']?.toString()));
  }

  @visibleForTesting
  void onRecoveryNotice(dynamic payload) {
    final data = _toMap(payload);
    _recoveryController.add(RecoveryNoticeEvent(
      caseId: data?['caseId']?.toString(),
      kind: data?['kind']?.toString(),
      title: data?['title']?.toString(),
      body: data?['body']?.toString(),
    ));
  }

  Map<String, dynamic>? _toMap(dynamic raw) => raw is Map
      ? raw.map((key, value) => MapEntry(key.toString(), value))
      : null;
}
