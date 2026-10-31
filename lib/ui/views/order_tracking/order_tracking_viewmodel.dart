import 'dart:async';
import 'dart:developer';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/core/network/api_result.dart' show LoadFailure;
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/transfer_payment.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/ui/views/order_tracking/order_driver_reader.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/tracking_routes.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_lib/maps/geo.dart';
import 'package:splg_lib/maps/route_tracker.dart';
import 'package:splg_lib/maps/vehicle_marker.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:splg_lib/theme/app_colors.dart';

enum TrackingStage {
  pending,
  assigned,
  inProgress,
  arriving,
  delivered,
  cancelled,
}

/// Cada cuánto se consulta el pedido por si el socket se cayó o dejó de
/// avisar.
const trackingPollInterval = Duration(seconds: 20);

class OrderTrackingViewModel extends BaseViewModel
    with WidgetsBindingObserver, TransferPayment {
  OrderTrackingViewModel({
    required this.orderId,
    this.pollInterval = trackingPollInterval,
    RouteTrackerFactory? routeTracker,
    Future<BitmapDescriptor?> Function()? iconLoader,
  })  : _customTracker = routeTracker,
        _iconLoader = iconLoader;

  final String orderId;
  final Duration pollInterval;
  final RouteTrackerFactory? _customTracker;
  final Future<BitmapDescriptor?> Function()? _iconLoader;

  /// Cuánto antes de `expiresAt` se renueva la foto firmada del chofer.
  static const photoRenewMargin = Duration(seconds: 30);

  /// Vida que se supone a la URL firmada de la foto cuando no trae sus datos
  /// de vencimiento (`X-Amz-Date` + `X-Amz-Expires`).
  static const eventPhotoTtl = Duration(minutes: 5);

  final _trackingService = locator<OrderTrackingService>();
  final _customerService = locator<CustomerService>();
  final _historyService = locator<HistoryService>();
  final _dialogService = locator<DialogService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _navigationService = locator<NavigationService>();

  /// La ruta por calles la da el back y sólo con el pedido en camino.
  RouteTracker _newTracker(LatLng destination) =>
      _customTracker?.call(destination) ??
      TrackingRoutes.trackerTo(
        destination,
        orderId: orderId,
        tokenProvider: () => _customerService.token,
        canRequest: () => _status == 'out_for_delivery',
      );

  GoogleMapController? _mapController;
  Order? _order;

  LatLng? _customerLocation;
  LatLng? _driverLocation;
  double _driverHeading = 0;
  BitmapDescriptor? _vehicleIcon;

  String _status = 'pending';

  /// Se suma con cada aviso del socket: una consulta que salió antes de un
  /// aviso trae un estado viejo y no lo pisa.
  int _eventVersion = 0;
  bool _suspended = false;
  bool _finishedHandled = false;
  bool _arrived = false;
  String? _driverId;
  bool _cancelling = false;
  String? _cancellationReason;

  /// Quién canceló, según el pedido o el aviso del socket.
  String? _cancelledBy;
  String? _loadError;
  bool _gone = false;
  DateTime? _driverLocationAt;
  bool _loadRetryable = true;
  int? _etaMinutes;
  DateTime? _etaDateTime;

  String _driverName = 'Repartidor';
  double? _driverRating;
  String? _vehicleName;
  String? _vehiclePlate;
  String? _driverPhone;
  String? _driverAvatarUrl;
  Timer? _photoTimer;
  bool _refreshingPhoto = false;
  bool _pollAgain = false;
  bool _closed = false;
  String? _sessionCustomerId;

  bool _userMovedMap = false;
  double _radarRadius = 60;

  Timer? _radarTimer;
  Timer? _pollTimer;
  bool _polling = false;
  StreamSubscription<DriverLocationUpdate>? _driverLocationSubscription;
  StreamSubscription<String>? _orderStatusSubscription;
  StreamSubscription<DriverInfo>? _driverSubscription;
  StreamSubscription<String>? _cancellationSubscription;
  StreamSubscription<String>? _cancelledBySubscription;
  StreamSubscription<void>? _arrivedSubscription;
  StreamSubscription<void>? _expressDegradedSubscription;
  StreamSubscription<void>? _orderChangedSubscription;

  RouteTracker? _tracker;
  Set<Polyline> _polylines = const {};

  /// El pedido llegó del back (aunque no se haya podido armar el detalle).
  bool _loaded = false;
  bool get hasOrderLoaded => _loaded;
  String? get loadError => _loadError;

  /// "Reintentar" sólo tiene sentido si no es la sesión la que venció.
  bool get canRetryLoad => _loadRetryable;
  LatLng get fallbackCenter => const LatLng(-27.3671, -55.8961);

  LatLng? get driverPosition => _driverLocation;
  double get driverHeading => _driverHeading;
  BitmapDescriptor? get vehicleIcon => _vehicleIcon;

  bool get isDelivered => _status == 'delivered';
  bool get isCancelled => _status == 'cancelled';
  bool get isFinished => isDelivered || isCancelled;

  TrackingStage get stage {
    switch (_status) {
      case 'delivered':
        return TrackingStage.delivered;
      case 'cancelled':
        return TrackingStage.cancelled;
      case 'accepted':
        return TrackingStage.assigned;
      case 'out_for_delivery':
        final distance = _distanceToCustomer;
        return _arrived || (distance != null && distance < 200)
            ? TrackingStage.arriving
            : TrackingStage.inProgress;
      default:
        return TrackingStage.pending;
    }
  }

  int get currentStepIndex {
    switch (stage) {
      case TrackingStage.pending:
        return 0;
      case TrackingStage.assigned:
        return 1;
      case TrackingStage.inProgress:
        return 2;
      case TrackingStage.arriving:
      case TrackingStage.delivered:
      case TrackingStage.cancelled:
        return 3;
    }
  }

  String get orderTitle {
    final suffix =
        orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    return 'Pedido #$suffix';
  }

  bool _isExpress = false;
  bool _expressDegraded = false;
  double _expressSurcharge = 0;
  bool _paidOnline = false;
  String _paymentStatus = 'pending';
  String? _loadedPaymentStatus;

  @override
  String get transferOrderId => orderId;
  @override
  bool get transferIsOnline => _order?.paymentMethod == PaymentMethod.online;
  @override
  bool get transferCancelled => isCancelled;
  @override
  String get transferPaymentStatus => _paymentStatus;

  /// Datos bancarios y comprobantes: se leen la primera vez y cada vez que el
  /// pago cambia de estado (p. ej. la distribuidora lo confirma).
  Future<void> _refreshTransfer() async {
    if (!transferIsOnline || _loadedPaymentStatus == _paymentStatus) return;
    _loadedPaymentStatus = _paymentStatus;
    await loadTransfer();
    if (!_closed) notifyListeners();
  }

  void _readExpress(Map<String, dynamic> raw) {
    _isExpress = raw['deliveryMode'] == 'express';
    _expressDegraded = !_isExpress && raw['expressDegradedAt'] != null;
    _paymentStatus = raw['paymentStatus']?.toString() ?? 'pending';
    _paidOnline = raw['paymentStatus'] == 'paid' &&
        raw['paymentMethod'] != null &&
        raw['paymentMethod'] != 'cash';
    final amount = raw['expressSurchargeAmount'];
    _expressSurcharge = amount is num
        ? amount.toDouble()
        : double.tryParse('${amount ?? ''}') ?? 0;
  }

  /// Aviso del express: busca moto, o ninguna aceptó y pasó al reparto común
  /// sin el recargo (que se descuenta, o se devuelve si ya se pagó en línea).
  /// Null si el pedido no es ni fue express.
  String? get expressNotice {
    if (_expressDegraded) {
      final amount =
          _expressSurcharge > 0 ? ' (${money.format(_expressSurcharge)})' : '';
      return 'Ningún repartidor en moto aceptó tu pedido express: pasó al '
          'reparto común. El recargo express$amount ya no se cobra.'
          '${_paidOnline ? ' Como lo pagaste en línea, se te devuelve.' : ''}';
    }
    if (_isExpress && stage == TrackingStage.pending) {
      return 'Pedido express: lo ofrecemos a repartidores en moto cercanos. '
          'Si ninguno lo acepta, pasa al reparto común sin el recargo.';
    }
    return null;
  }

  String get statusTitle {
    switch (stage) {
      case TrackingStage.pending:
        return 'Buscando al repartidor más cercano...';
      case TrackingStage.assigned:
        return '${_driverFirstName()} fue asignado a tu pedido';
      case TrackingStage.inProgress:
        return '${_driverFirstName()} está en camino';
      case TrackingStage.arriving:
        return 'Tu garrafa está llegando';
      case TrackingStage.delivered:
        return 'Entregamos tu pedido';
      case TrackingStage.cancelled:
        return 'Pedido cancelado';
    }
  }

  String get etaTitle {
    if (stage == TrackingStage.arriving) {
      return '¡Ya está afuera!';
    }
    if (_etaMinutes != null) {
      return 'Llega en $_etaMinutes min';
    }
    return 'Calculando llegada...';
  }

  String get etaSubtitle {
    if (stage == TrackingStage.arriving) {
      return 'Salí a recibirla';
    }
    if (_etaDateTime == null) {
      return 'Hora estimada: --:--';
    }
    return 'Hora estimada: ${DateFormat('HH:mm').format(_etaDateTime!)}';
  }

  /// Texto de la tarjeta de pedido finalizado ("Entregamos..." / motivo de la
  /// cancelación que informa el back).
  String? get finishedDetail {
    if (isDelivered) return 'Gracias por tu compra.';
    if (isCancelled) {
      final who = switch (_cancelledBy) {
        'customer' => 'Lo cancelaste vos.',
        'admin' => 'Lo canceló la distribuidora.',
        'driver' => 'Lo canceló el repartidor.',
        'system' => 'Se canceló automáticamente.',
        _ => null,
      };
      final reason = _cancellationReason;
      // Sin motivo propio el back escribe "Cancelado por <rol>", que repite lo
      // que ya dice [who].
      final reasonText =
          reason == null || (who != null && reason.startsWith('Cancelado por '))
              ? null
              : 'Motivo: $reason';
      final text = [who, reasonText].whereType<String>().join(' ');
      return text.isEmpty ? null : text;
    }
    return null;
  }

  String get driverName => _driverName;
  double? get driverRating => _driverRating;
  String? get vehicleName => _vehicleName;
  String? get vehiclePlate => _vehiclePlate;
  String? get driverAvatarUrl => _driverAvatarUrl;
  bool get hasDriverPhone => _driverPhone?.trim().isNotEmpty ?? false;

  /// Por qué "Llamar" y "Escribirle" no se pueden usar todavía.
  String? get contactHint => hasDriverPhone
      ? null
      : 'Todavía no tenemos el teléfono de tu repartidor.';

  String get driverInitials {
    final parts = _driverName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = String.fromCharCode(parts.first.runes.first).toUpperCase();
    if (parts.length == 1) return first;
    return first + String.fromCharCode(parts.last.runes.first).toUpperCase();
  }

  bool get showDriverCard =>
      stage == TrackingStage.assigned ||
      stage == TrackingStage.inProgress ||
      stage == TrackingStage.arriving;
  bool get showRadar => stage == TrackingStage.pending;

  /// Sólo un pedido que todavía no tiene repartidor se cancela desde acá.
  bool get canCancelOrder => _status == 'pending';
  bool get showArrivingBanner => stage == TrackingStage.arriving;

  /// El chofer solo genera el QR de entrega una vez que el pedido esta
  /// `on_the_way` (mapeado internamente a `out_for_delivery`). Se chequea el
  /// status normalizado en vez de `stage`, porque `stage` ya devuelve
  /// `arriving` por cercania GPS aunque el status siga siendo el mismo.
  bool get canConfirmDelivery => _status == 'out_for_delivery';

  String get compactOrderDetail {
    if (_order == null || _order!.items.isEmpty) {
      return 'Detalle no disponible';
    }
    final itemsSummary = _order!.items
        .map((item) => '${item.quantity}x ${_itemTitle(item)}')
        .join(' - ');
    final total = money.format(_order!.total);
    return '$itemsSummary - Total: $total';
  }

  List<String> get expandedOrderDetail {
    if (_order == null || _order!.items.isEmpty) {
      return const [];
    }
    return _order!.items
        .map((item) => '${item.quantity}x ${_itemTitle(item)}')
        .toList();
  }

  /// Marcadores fijos (la dirección); el repartidor lo dibuja
  /// `SplgAnimatedVehicle` con su ícono de camioneta.
  Set<Marker> get markers {
    if (_customerLocation == null) return const {};
    return {
      Marker(
        markerId: const MarkerId('customer_home'),
        position: _customerLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        ),
        infoWindow: const InfoWindow(title: 'Tu dirección'),
      ),
    };
  }

  /// Ruta que le falta recorrer al repartidor, punteada si no hay ruta por
  /// calles.
  Set<Polyline> get polylines => _polylines;

  Set<Circle> get circles {
    if (!showRadar || _customerLocation == null) {
      return const {};
    }
    return {
      Circle(
        circleId: const CircleId('searching_radar'),
        center: _customerLocation!,
        radius: _radarRadius,
        fillColor: AppColors.primary.withAlpha(30),
        strokeColor: AppColors.primary.withAlpha(120),
        strokeWidth: 1,
      ),
    };
  }

  Future<void> initialize() async {
    setBusy(true);
    _sessionCustomerId = _customerService.customer.customerId;
    _customerService.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
    await _loadTrackingData();
    if (_closed) return;
    if (_gone) {
      setBusy(false);
      return;
    }
    if (isFinished) _finish();
    await _startRealtimeTracking();
    if (_closed) return;
    unawaited(_loadVehicleIcon());
    await refreshDriverPhoto();
    if (_closed) return;
    _syncRadarState();
    _startPolling();
    setBusy(false);
  }

  /// Vuelve a pedir el pedido cuando la primera carga falló, y retoma lo que
  /// la carga fallida dejó sin hacer (foto, cierre, sondeo).
  Future<void> retry() async {
    setBusy(true);
    final ok = await _loadTrackingData();
    if (_closed) return;
    if (ok) {
      _afterStatusChange(photo: false);
      await refreshDriverPhoto();
      _startPolling();
    }
    if (!_closed) setBusy(false);
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToMarkers(force: true);
  }

  void onMapMovedByUser() {
    _userMovedMap = true;
  }

  Future<void> recenterMap() async {
    _userMovedMap = false;
    await _fitMapToMarkers(force: true);
  }

  Future<void> callDriver() async {
    if (!hasDriverPhone) {
      await _dialogService.showDialog(
        title: 'Teléfono no disponible',
        description: 'Todavía no tenemos un número de contacto del repartidor.',
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: _driverPhone!.trim());
    final launched = await launchUrl(telUri);
    if (!launched) {
      await _dialogService.showDialog(
        title: 'No se pudo llamar',
        description: 'No pudimos abrir el marcador del teléfono.',
      );
    }
  }

  Future<void> messageDriver() async {
    if (!hasDriverPhone) {
      await _dialogService.showDialog(
        title: 'Contacto no disponible',
        description:
            'Todavía no tenemos un número para escribirle al repartidor.',
      );
      return;
    }

    final normalizedPhone = _driverPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedPhone.isEmpty) {
      await _dialogService.showDialog(
        title: 'Contacto no disponible',
        description: 'El número del repartidor no es válido.',
      );
      return;
    }

    final message = Uri.encodeComponent(
      'Hola, te escribo por mi pedido $orderTitle.',
    );
    final waUri = Uri.parse('https://wa.me/$normalizedPhone?text=$message');
    final launched = await launchUrl(
      waUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await _dialogService.showDialog(
        title: 'No se pudo abrir WhatsApp',
        description: 'Probá llamarlo para coordinar la entrega.',
      );
    }
  }

  /// Cancelar desde el seguimiento usa el mismo flujo que el detalle del
  /// pedido: pantalla con motivo y confirmación.
  Future<void> cancelOrder() async {
    if (_cancelling || !canCancelOrder) return;
    _cancelling = true;
    try {
      final cancelled =
          await _navigationService.navigateToCancelOrderView(orderId: orderId);
      if (cancelled != true || _closed) return;
      _trackingService.disconnect();
      _navigationService.back();
    } finally {
      _cancelling = false;
    }
  }

  /// Abre la camara para escanear el QR que muestra el chofer al llegar. La
  /// confirmacion contra el backend (y sus dialogs de exito/error) se hacen
  /// dentro de QrScanView; aca solo reaccionamos si volvio confirmada.
  Future<void> confirmDeliveryByScan() async {
    final delivered = await _navigationService.navigateToQrScanView(
      orderId: orderId,
    );
    if (delivered != true) {
      return;
    }
    await _finishDelivered();
  }

  /// Alternativa al escáner: el cliente tipea el código que muestra el chofer.
  /// La hoja confirma contra el backend y muestra ahí sus rechazos.
  Future<void> confirmDeliveryByCode() async {
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.deliveryCode,
      isScrollControlled: true,
      data: {'orderId': orderId},
    );
    if (response?.confirmed != true || _closed) return;
    await _dialogService.showDialog(
      title: '¡Entrega confirmada!',
      description: 'Gracias por tu compra.',
    );
    await _finishDelivered();
  }

  Future<void> _finishDelivered() async {
    // El pedido ya quedo `delivered` en el backend: refrescamos el historial
    // (para que Home/History lo muestren al toque) y cerramos el tracking,
    // que no tiene mas nada que seguir.
    await _historyService.tryRefreshHistory();
    _trackingService.disconnect();

    // Momento de mayor señal para calificar al chofer (CU-025). El cliente
    // puede omitir; el sheet maneja el envío y sus errores internamente.
    await rateDriver();

    _navigationService.back();
  }

  /// Ofrece calificar al chofer tras la entrega. `POST /ratings` requiere que
  /// el pedido esté `delivered`.
  Future<void> rateDriver() async {
    await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.rateDriver,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId, 'driverName': _driverName},
    );
  }

  /// Cierra el seguimiento de un pedido que ya terminó.
  void close() {
    _trackingService.disconnect();
    _navigationService.back();
  }

  Future<void> showHelp() async {
    await _dialogService.showDialog(
      title: 'Ayuda',
      description:
          'Acá ves el estado de tu pedido, dónde está tu repartidor y cuánto falta para que llegue.',
    );
  }

  /// Carga el pedido; devuelve false (y deja [loadError]) si no se pudo.
  Future<bool> _loadTrackingData() async {
    final version = _eventVersion;
    final token = await _customerService.token;
    if (token == null) {
      _loadError = ApiErrorText.sessionExpired;
      _loadRetryable = false;
      return false;
    }

    Map<String, dynamic>? raw;
    try {
      raw = await _trackingService.fetchOrderById(orderId, token);
    } on LoadFailure catch (e) {
      if (!_closed) _onOrderGone(e.message);
      return false;
    }
    if (raw == null || _closed) {
      _loadError ??= 'No pudimos cargar tu pedido. Revisá tu conexión.';
      _loadRetryable = true;
      return false;
    }

    _loadError = null;
    _loaded = true;
    _applyOrder(raw, fresh: version == _eventVersion);
    _updateEta();
    return true;
  }

  /// El back dice que el pedido no existe o ya no es del cliente (404/410):
  /// se corta todo lo que lo seguía (sondeo, socket, radar) y se avisa. Si la
  /// pantalla ya mostraba el pedido, se explica y se vuelve; si no, queda el
  /// mensaje con "Volver".
  void _onOrderGone(String message) {
    if (_gone) return;
    _gone = true;
    _loadError = message;
    _loadRetryable = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _radarTimer?.cancel();
    _radarTimer = null;
    _clearDriverPhoto();
    _trackingService.disconnect();
    if (_loaded) unawaited(_leaveGoneOrder(message));
  }

  Future<void> _leaveGoneOrder(String message) async {
    await _dialogService.showDialog(
      title: 'Pedido no disponible',
      description: message,
      buttonTitle: 'Aceptar',
    );
    if (!_closed) _navigationService.back();
  }

  /// [fresh] es false si mientras se pedía llegó un aviso por el socket: el
  /// estado y el repartidor de esta respuesta ya pueden estar viejos.
  void _applyOrder(Map<String, dynamic> raw, {bool fresh = true}) {
    _order = OrderApiMapper.parseOrder(raw);
    _readExpress(raw);
    unawaited(_refreshTransfer());
    _cancellationReason =
        _readString(raw, const ['cancellation_reason']) ?? _cancellationReason;
    _cancelledBy = _readString(raw, const ['cancelledBy']) ?? _cancelledBy;
    if (isFinished || !fresh) return;

    final statusFromOrder = _order?.status == OrderStatus.outForDelivery
        ? 'out_for_delivery'
        : _order?.status.name;
    _setStatus(_readString(raw, const ['status']) ?? statusFromOrder);
    _setDriverData(raw);
    _setCustomerLocationFromOrder(raw);
    _updateEta();
    _rebuildPolylines();
    unawaited(_updateRoute());
  }

  // --- Sondeo de respaldo -------------------------------------------------

  void _startPolling() {
    // `cancel()` no pone el campo en null: sin esto un sondeo cancelado antes
    // (p. ej. tras "Reintentar") impedía crear el nuevo.
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_closed || _suspended || _gone || isFinished) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => poll());
  }

  /// Consulta el pedido por si el socket se cayó o no avisó un cambio. Si el
  /// estado cambió, hace lo mismo que si hubiera llegado por el socket.
  Future<void> poll() async {
    if (_closed || _suspended || _gone || isFinished) return;
    if (_polling) {
      // Hay una consulta en curso que pudo quedar vieja por un aviso del
      // socket: se repite apenas termina.
      _pollAgain = true;
      return;
    }
    _polling = true;
    try {
      final before = _status;
      final hadError = _loadError != null;
      final noticeBefore = expressNotice;
      final ok = await _loadTrackingData();
      if (_closed) return;
      // El express pasó al reparto común sin cambiar el estado: el aviso cambia.
      if (ok && expressNotice != noticeBefore) rebuildUi();
      if (ok && (_status != before || hadError)) {
        _afterStatusChange();
      }
    } catch (e) {
      log('e in poll tracking: ${e.runtimeType}');
    } finally {
      _polling = false;
      if (_pollAgain) {
        _pollAgain = false;
        unawaited(poll());
      }
    }
  }

  Future<void> _startRealtimeTracking() async {
    if (_closed || _gone || isFinished) return;
    _driverLocationSubscription?.cancel();
    _orderStatusSubscription?.cancel();
    _cancellationSubscription?.cancel();
    _cancelledBySubscription?.cancel();
    _arrivedSubscription?.cancel();
    _expressDegradedSubscription?.cancel();
    _orderChangedSubscription?.cancel();

    _driverLocationSubscription = _trackingService.driverLocationUpdates.listen(
      (update) {
        final position = LatLng(update.lat, update.lng);
        _driverHeading = resolveHeading(
          gpsHeading: update.heading != 0 ? update.heading : null,
          speedMps: update.heading != 0 ? 1.0 : null,
          previous: _driverLocation,
          current: position,
          fallback: _driverHeading,
        );
        _driverLocation = position;
        _driverLocationAt = update.at ?? DateTime.now();
        _updateEta();
        _rebuildPolylines();
        unawaited(_updateRoute());
        _syncRadarState();
        _fitMapToMarkers();
        rebuildUi();
      },
    );

    _driverSubscription?.cancel();
    _driverSubscription = _trackingService.driverUpdates.listen(_onDriverEvent);

    _cancellationSubscription =
        _trackingService.cancellationReasons.listen((reason) {
      _cancellationReason = reason;
    });

    _cancelledBySubscription =
        _trackingService.cancelledBys.listen((who) => _cancelledBy = who);

    _expressDegradedSubscription = _trackingService.expressDegradedUpdates
        .listen((_) => unawaited(poll()));

    // Modificado, pago aprobado o reintegrado: se vuelve a leer el pedido.
    _orderChangedSubscription =
        _trackingService.orderChanges.listen((_) => unawaited(poll()));

    _arrivedSubscription = _trackingService.arrivedUpdates.listen((_) {
      if (_status != 'out_for_delivery') return;
      _arrived = true;
      rebuildUi();
    });

    _orderStatusSubscription = _trackingService.orderStatusUpdates.listen(
      (status) {
        _eventVersion++;
        _setStatus(status);
        _afterStatusChange();
        // El socket sólo trae el estado: el repartidor y su vehículo se leen
        // del pedido.
        if (_hasDriverAssigned) {
          unawaited(poll().then((_) {
            if (!_closed) rebuildUi();
          }));
        }
      },
    );

    // El token se pide en cada (re)conexión: el de Firebase vence en una hora.
    _trackingService.subscribeToOrder(
      orderId: orderId,
      customerId: _customerService.customer.customerId,
      tokenProvider: () => _customerService.token,
    );
  }

  /// Lo que hay que hacer cuando el estado pudo haber cambiado (por socket o
  /// por el sondeo).
  void _afterStatusChange({bool photo = true}) {
    if (_closed) return;
    if (_status != 'out_for_delivery') _arrived = false;
    // Sin repartidor (se buscaba o lo liberó): no quedan sus datos.
    if (_status == 'pending' || _status == 'reserved') _clearDriver();
    if (_hasDriverAssigned) {
      if (photo && _driverAvatarUrl == null) refreshDriverPhoto();
    } else {
      _clearDriverPhoto();
    }
    if (isFinished) {
      if (!_finishedHandled) _finish();
    } else {
      unawaited(_updateRoute());
    }
    _syncRadarState();
    rebuildUi();
  }

  /// El pedido terminó (entregado o cancelado): no hay nada más que seguir.
  void _finish() {
    _finishedHandled = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _tracker = null;
    _polylines = const {};
    _trackingService.disconnect();
    // El aviso por socket de una cancelación no siempre trae el motivo; se lee
    // del pedido.
    if (isCancelled && (_cancellationReason == null || _cancelledBy == null)) {
      unawaited(_loadTrackingData().then((_) {
        if (!_closed) rebuildUi();
      }));
    }
  }

  void _setCustomerLocationFromOrder(Map<String, dynamic> raw) {
    LatLng? location;

    if (_order?.address?.latitude != null &&
        _order?.address?.longitude != null) {
      final lat = double.tryParse(_order!.address!.latitude!);
      final lng = double.tryParse(_order!.address!.longitude!);
      if (lat != null && lng != null) {
        location = LatLng(lat, lng);
      }
    }

    location ??= _readLatLng(
      _readMap(raw, const ['delivery_address']),
    );

    _customerLocation = location;
  }

  void _setDriverData(Map<String, dynamic> raw) {
    final driver = OrderDriverReader.read(raw);
    // Otro repartidor (reasignación): no quedan el teléfono ni la
    // calificación del anterior.
    if (driver.id != null && _driverId != null && driver.id != _driverId) {
      _clearDriver();
    }
    _driverId = driver.id ?? _driverId;
    _driverName = driver.name ?? _driverName;
    // El bloque `driver` del pedido es la fuente: el back lo manda sólo con el
    // pedido aceptado o en camino. Sin él no hay teléfono ni calificación (ni
    // se inventan), y el estado se muestra sin chofer.
    _driverPhone = driver.phone;
    _driverRating = driver.rating;
    if (!driver.hasBlock && !_hasDriverAssigned) _clearDriver();
    // El vehículo lo informa siempre el back con el pedido: lo que no trae,
    // no hay.
    _vehicleName = driver.vehicleName;
    _vehiclePlate = driver.vehiclePlate;
    // La ubicación llega sólo en camino y reciente; null es "sin posición
    // reciente", no un error, y no pisa una posición más nueva del socket.
    final last = driver.lastLocation, at = driver.lastLocationAt;
    final known = _driverLocationAt;
    // Sin hora (`at: null`) no se puede comparar: sirve sólo si todavía no hay
    // otra posición con hora.
    if (last != null && (known == null || (at != null && at.isAfter(known)))) {
      _driverLocation = last;
      _driverLocationAt = at ?? _driverLocationAt;
    }
  }

  /// Olvida todo lo del repartidor (se liberó el pedido o lo tomó otro).
  void _clearDriver() {
    _driverName = 'Repartidor';
    _driverId = null;
    _driverPhone = null;
    _driverRating = null;
    _vehicleName = null;
    _vehiclePlate = null;
    _driverLocation = null;
    _driverLocationAt = null;
    _driverHeading = 0;
    _etaMinutes = null;
    _etaDateTime = null;
    _tracker = null;
    _polylines = const {};
    _arrived = false;
    _clearDriverPhoto();
  }

  /// La foto sólo existe con el pedido aceptado o en camino.
  bool get _hasDriverAssigned =>
      _status == 'accepted' || _status == 'out_for_delivery';

  void _onDriverEvent(DriverInfo driver) {
    if (driver.name != null && driver.name != _driverName) {
      // Otro repartidor: no quedan los datos del anterior.
      _driverPhone = null;
      _driverRating = null;
      _driverId = null;
      _vehicleName = null;
      _vehiclePlate = null;
      _driverName = driver.name!;
    }
    if (driver.phone != null) _driverPhone = driver.phone;
    if (driver.photoUrl != null) {
      _setDriverPhoto(driver.photoUrl!, _expiryOf(driver.photoUrl!));
    } else {
      _clearDriverPhoto();
      refreshDriverPhoto();
    }
    rebuildUi();
  }

  /// Cuándo vence una URL firmada: lo dice ella misma (`X-Amz-Date` +
  /// `X-Amz-Expires`); sólo si no lo trae se supone [eventPhotoTtl].
  DateTime _expiryOf(String url) =>
      SignedUrl.fromAwsQuery(url) ?? DateTime.now().add(eventPhotoTtl);

  /// Pide una URL firmada nueva (`GET /orders/:id/driver-photo?modo=url`).
  /// 409/404 dejan al chofer sin foto, sin mostrar error.
  Future<void> refreshDriverPhoto() async {
    if (_closed || _refreshingPhoto || !_hasDriverAssigned) return;
    final token = await _customerService.token;
    if (_closed || token == null) return;
    _refreshingPhoto = true;
    try {
      final lookup = await _trackingService.fetchDriverPhoto(orderId, token);
      if (_closed || !_hasDriverAssigned) return;
      if (lookup.url != null) {
        _setDriverPhoto(
            lookup.url!, lookup.expiresAt ?? _expiryOf(lookup.url!));
      } else if (!lookup.failed) {
        _clearDriverPhoto();
      }
      rebuildUi();
    } finally {
      _refreshingPhoto = false;
    }
  }

  void _setDriverPhoto(String url, DateTime expiresAt) {
    _driverAvatarUrl = url;
    _photoTimer?.cancel();
    var wait = expiresAt.subtract(photoRenewMargin).difference(DateTime.now());
    if (wait < const Duration(seconds: 1)) wait = const Duration(seconds: 1);
    _photoTimer = Timer(wait, refreshDriverPhoto);
  }

  void _clearDriverPhoto() {
    _photoTimer?.cancel();
    _photoTimer = null;
    _driverAvatarUrl = null;
  }

  Future<void> _loadVehicleIcon() async {
    try {
      final loader = _iconLoader ??
          () => SplgVehicleIcon.descriptor(body: AppColors.llama600);
      final icon = await loader();
      if (_closed || icon == null) return;
      _vehicleIcon = icon;
      rebuildUi();
    } catch (e) {
      log('No se pudo dibujar el ícono del vehículo: ${e.runtimeType}');
    }
  }

  void _onSessionChanged() {
    if (_customerService.customer.customerId != _sessionCustomerId) {
      _clearDriverPhoto();
      rebuildUi();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    } else {
      _suspend();
    }
  }

  /// En segundo plano no hay nada que mirar: se cortan el sondeo, el radar, el
  /// renovado de la foto y el socket.
  void _suspend() {
    if (_closed || _suspended) return;
    _suspended = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _radarTimer?.cancel();
    _radarTimer = null;
    _photoTimer?.cancel();
    _photoTimer = null;
    _trackingService.disconnect();
  }

  /// De vuelta en primer plano: relee el pedido (pudo cambiar) y retoma todo.
  Future<void> _resume() async {
    if (_closed || !_suspended) return;
    _suspended = false;
    if (isFinished) return;
    final ok = await _loadTrackingData();
    if (_closed || _suspended) return;
    await _startRealtimeTracking();
    if (ok) _afterStatusChange();
    unawaited(refreshDriverPhoto());
    _syncRadarState();
    _startPolling();
  }

  void _setStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      return;
    }

    _status = _normalizeStatus(status);
  }

  /// Llegada estimada: por la ruta si se conoce su duración; si no, por la
  /// distancia en línea recta a ~18 km/h.
  void _updateEta() {
    final position = _driverLocation;
    final distance = _distanceToCustomer;
    if (position == null || distance == null) {
      return;
    }

    if (distance < 200) {
      _etaMinutes = 0;
      _etaDateTime = DateTime.now();
      return;
    }

    final seconds = _tracker?.remainingSeconds(position);
    final minutes = seconds != null
        ? max(1, (seconds / 60).round())
        : max(1, ((distance / 1000) / 18 * 60).round());
    _etaMinutes = minutes;
    _etaDateTime = DateTime.now().add(Duration(minutes: minutes));
  }

  bool get _routeVisible =>
      stage == TrackingStage.assigned ||
      stage == TrackingStage.inProgress ||
      stage == TrackingStage.arriving;

  void _rebuildPolylines() {
    final position = _driverLocation, tracker = _tracker;
    if (position == null || tracker == null || !_routeVisible) {
      _polylines = const {};
      return;
    }
    _polylines = {
      splgRoutePolyline(
        tracker.remainingPoints(position),
        color: AppColors.llama600,
        dashed: tracker.route?.isFallback ?? true,
      ),
    };
  }

  Future<void> _updateRoute() async {
    final destination = _customerLocation, position = _driverLocation;
    if (destination == null || position == null || _closed || !_routeVisible) {
      return;
    }
    final tracker = _tracker ??= _newTracker(destination);
    try {
      final changed = await tracker.update(position);
      if (_closed || !identical(tracker, _tracker)) return;
      if (changed) {
        _rebuildPolylines();
        _updateEta();
        rebuildUi();
      }
    } catch (e) {
      log('No se pudo actualizar la ruta: ${e.runtimeType}');
    }
  }

  Future<void> _fitMapToMarkers({bool force = false}) async {
    if (_mapController == null) {
      return;
    }

    if (!force && _userMovedMap) {
      return;
    }

    if (_customerLocation == null && _driverLocation == null) {
      return;
    }

    if (_driverLocation == null || _customerLocation == null) {
      final target = _driverLocation ?? _customerLocation!;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 15),
        ),
      );
      return;
    }

    final swLat = min(_customerLocation!.latitude, _driverLocation!.latitude);
    final swLng = min(_customerLocation!.longitude, _driverLocation!.longitude);
    final neLat = max(_customerLocation!.latitude, _driverLocation!.latitude);
    final neLng = max(_customerLocation!.longitude, _driverLocation!.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(
        swLat == neLat ? swLat - 0.001 : swLat,
        swLng == neLng ? swLng - 0.001 : swLng,
      ),
      northeast: LatLng(
        swLat == neLat ? neLat + 0.001 : neLat,
        swLng == neLng ? neLng + 0.001 : neLng,
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 90),
    );
  }

  void _syncRadarState() {
    if (_closed || _suspended || !showRadar) {
      _radarTimer?.cancel();
      _radarTimer = null;
      _radarRadius = 60;
      return;
    }

    if (_radarTimer != null) {
      return;
    }

    _radarTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _radarRadius += 45;
      if (_radarRadius > 240) {
        _radarRadius = 60;
      }
      rebuildUi();
    });
  }

  /// El back manda `on_the_way` por socket y `out_for_delivery` en el pedido.
  String _normalizeStatus(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    return status == 'on_the_way' ? 'out_for_delivery' : status;
  }

  String _driverFirstName() {
    final trimmed = _driverName.trim();
    if (trimmed.isEmpty) {
      return 'El repartidor';
    }
    return trimmed.split(' ').first;
  }

  String _itemTitle(OrderItem item) {
    final type = item.cylinder.type.trim();
    if (type.isNotEmpty) {
      return type;
    }
    final description = item.cylinder.description.trim();
    if (description.isEmpty || description.length > 120) {
      return 'Garrafa';
    }
    return description;
  }

  double? get _distanceToCustomer {
    if (_driverLocation == null || _customerLocation == null) {
      return null;
    }
    return Geo.distanceMeters(_driverLocation!, _customerLocation!);
  }

  LatLng? _readLatLng(Map<String, dynamic>? map) {
    if (map == null) return null;
    final lat = _readDouble(map['latitude']);
    final lng = _readDouble(map['longitude']);
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) {
      return null;
    }
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return null;
  }

  String? _readString(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) {
      return null;
    }
    for (final key in keys) {
      final value = source[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    _closed = true;
    _clearDriverPhoto();
    _customerService.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _driverSubscription?.cancel();
    _radarTimer?.cancel();
    _pollTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _orderStatusSubscription?.cancel();
    _cancellationSubscription?.cancel();
    _cancelledBySubscription?.cancel();
    _arrivedSubscription?.cancel();
    _expressDegradedSubscription?.cancel();
    _orderChangedSubscription?.cancel();
    _trackingService.disconnect();
    super.dispose();
  }
}
