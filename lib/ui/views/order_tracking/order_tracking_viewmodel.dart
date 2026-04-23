import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/data/mappers/order_api_mapper.dart';
import 'package:jennigas_customer/services/customer_service.dart';
import 'package:jennigas_customer/services/history_service.dart';
import 'package:jennigas_customer/services/order_tracking_service.dart';
import 'package:jennygas_lib/domain/order.dart';
import 'package:jennygas_lib/domain/order_item.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';

enum TrackingStage {
  pending,
  assigned,
  inProgress,
  arriving,
}

class OrderTrackingViewModel extends BaseViewModel {
  OrderTrackingViewModel({required this.orderId});

  final String orderId;

  final _trackingService = locator<OrderTrackingService>();
  final _customerService = locator<CustomerService>();
  final _historyService = locator<HistoryService>();
  final _dialogService = locator<DialogService>();
  final _navigationService = locator<NavigationService>();

  GoogleMapController? _mapController;
  Order? _order;

  LatLng? _customerLocation;
  LatLng? _driverLocation;
  double _driverHeading = 0;

  String _status = 'pending';
  int? _etaMinutes;
  DateTime? _etaDateTime;

  String _driverName = 'Repartidor';
  double? _driverRating;
  String _vehicleName = 'Vehiculo sin datos';
  String _vehiclePlate = '--';
  String? _driverPhone;
  String? _driverAvatarUrl;

  bool _detailsExpanded = false;
  bool _userMovedMap = false;
  bool _arrivingNotified = false;
  double _radarRadius = 60;

  Timer? _radarTimer;
  StreamSubscription<DriverLocationUpdate>? _driverLocationSubscription;
  StreamSubscription<String>? _orderStatusSubscription;

  final List<LatLng> _routePoints = [];
  LatLng? _lastRouteOrigin;

  bool get hasOrderLoaded => _order != null;
  bool get detailsExpanded => _detailsExpanded;
  LatLng get fallbackCenter => const LatLng(-34.6037, -58.3816);

  TrackingStage get stage {
    final distance = _distanceToCustomer;
    if (distance != null && distance < 200) {
      return TrackingStage.arriving;
    }

    switch (_status) {
      case 'accepted':
        return TrackingStage.assigned;
      case 'out_for_delivery':
        return TrackingStage.inProgress;
      case 'arriving':
        return TrackingStage.arriving;
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
        return 3;
    }
  }

  String get orderTitle {
    final suffix = orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    return 'Pedido #$suffix';
  }

  String get statusTitle {
    switch (stage) {
      case TrackingStage.pending:
        return 'Buscando al repartidor mas cercano...';
      case TrackingStage.assigned:
        return '${_driverFirstName()} fue asignado';
      case TrackingStage.inProgress:
        return '${_driverFirstName()} esta en camino';
      case TrackingStage.arriving:
        return 'Tu garrafa esta llegando';
    }
  }

  String get etaTitle {
    if (stage == TrackingStage.arriving) {
      return 'Esta afuera!';
    }
    if (_etaMinutes != null) {
      return 'Llega en $_etaMinutes min';
    }
    return 'Calculando llegada...';
  }

  String get etaSubtitle {
    if (stage == TrackingStage.arriving) {
      return 'Por favor sali a recibirla';
    }
    if (_etaDateTime == null) {
      return 'Hora estimada: --:--';
    }
    return 'Hora estimada: ${DateFormat('HH:mm').format(_etaDateTime!)}';
  }

  String get driverName => _driverName;
  String get driverRatingText =>
      _driverRating == null ? '--' : _driverRating!.toStringAsFixed(1);
  String get vehicleName => _vehicleName;
  String get vehiclePlate => _vehiclePlate;
  String? get driverAvatarUrl => _driverAvatarUrl;

  bool get showDriverCard => stage != TrackingStage.pending;
  bool get showRadar => stage == TrackingStage.pending;
  bool get canCancelOrder => stage == TrackingStage.pending;
  bool get showArrivingBanner => stage == TrackingStage.arriving;

  String get compactOrderDetail {
    if (_order == null || _order!.items.isEmpty) {
      return 'Detalle no disponible';
    }
    final itemsSummary = _order!.items
        .map((item) => '${item.quantity}x ${_itemTitle(item)}')
        .join(' - ');
    final total = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0',
    ).format(_order!.total);
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

  Set<Marker> get markers {
    final markers = <Marker>{};
    if (_customerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer_home'),
          position: _customerLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Tu casa'),
        ),
      );
    }

    if (_driverLocation != null && stage != TrackingStage.pending) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          rotation: _driverHeading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: _driverName),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get polylines {
    if (_routePoints.length < 2 || stage == TrackingStage.pending) {
      return const {};
    }
    return {
      Polyline(
        polylineId: const PolylineId('driver_route'),
        points: _routePoints,
        color: Colors.blue,
        width: 5,
        geodesic: true,
      ),
    };
  }

  Set<Circle> get circles {
    if (!showRadar || _customerLocation == null) {
      return const {};
    }
    return {
      Circle(
        circleId: const CircleId('searching_radar'),
        center: _customerLocation!,
        radius: _radarRadius,
        fillColor: Colors.blue.withAlpha(30),
        strokeColor: Colors.blue.withAlpha(120),
        strokeWidth: 1,
      ),
    };
  }

  Future<void> initialize() async {
    setBusy(true);
    await _loadTrackingData();
    await _startRealtimeTracking();
    _syncRadarState();
    setBusy(false);
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

  void toggleOrderDetails() {
    _detailsExpanded = !_detailsExpanded;
    rebuildUi();
  }

  Future<void> callDriver() async {
    if (_driverPhone == null || _driverPhone!.trim().isEmpty) {
      await _dialogService.showDialog(
        title: 'Telefono no disponible',
        description: 'No hay un numero de contacto para este chofer.',
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: _driverPhone!.trim());
    final launched = await launchUrl(telUri);
    if (!launched) {
      await _dialogService.showDialog(
        title: 'No se pudo llamar',
        description: 'No fue posible abrir el marcador del telefono.',
      );
    }
  }

  Future<void> messageDriver() async {
    if (_driverPhone == null || _driverPhone!.trim().isEmpty) {
      await _dialogService.showDialog(
        title: 'Contacto no disponible',
        description: 'No hay un numero para enviar mensaje al chofer.',
      );
      return;
    }

    final normalizedPhone = _driverPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedPhone.isEmpty) {
      await _dialogService.showDialog(
        title: 'Contacto no disponible',
        description: 'El numero del chofer no es valido.',
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
        description: 'Intenta llamar al chofer para coordinar la entrega.',
      );
    }
  }

  Future<void> cancelOrder() async {
    setBusy(true);
    final success = await _historyService.cancelOrder(orderId);
    setBusy(false);

    if (!success) {
      await _dialogService.showDialog(
        title: 'No se pudo cancelar',
        description: 'Intenta nuevamente en unos segundos.',
      );
      return;
    }

    _trackingService.disconnect();
    _navigationService.back();
  }

  Future<void> showHelp() async {
    await _dialogService.showDialog(
      title: 'Ayuda',
      description:
          'Esta pantalla muestra el estado de tu pedido, la ubicacion del chofer y el tiempo estimado de llegada.',
    );
  }

  Future<void> _loadTrackingData() async {
    final token = await _customerService.token;
    if (token == null) {
      return;
    }

    final raw = await _trackingService.fetchOrderById(orderId, token);
    if (raw == null) {
      return;
    }

    _order = OrderApiMapper.parseOrder(raw);

    final statusFromOrder = _order?.status == OrderStatus.outForDelivery
        ? 'out_for_delivery'
        : _order?.status.name;
    _setStatus(
      _readString(raw, const ['status', 'order_status']) ?? statusFromOrder,
    );
    _setDriverData(raw);
    _setCustomerLocationFromOrder(raw);
    _setDriverLocationFromPayload(raw);
    _setEtaFromPayload(raw);
    _updateEtaFromDistance();
    _updateRoute(force: true);
  }

  Future<void> _startRealtimeTracking() async {
    final token = await _customerService.token;

    _driverLocationSubscription?.cancel();
    _orderStatusSubscription?.cancel();

    _driverLocationSubscription = _trackingService.driverLocationUpdates.listen(
      (update) {
        _driverHeading = update.heading;
        _driverLocation = LatLng(update.lat, update.lng);
        _updateEtaFromDistance();
        _updateRoute();
        _syncRadarState();
        _fitMapToMarkers();
        rebuildUi();
      },
    );

    _orderStatusSubscription = _trackingService.orderStatusUpdates.listen(
      (status) {
        _setStatus(status);
        _syncRadarState();
        rebuildUi();
      },
    );

    _trackingService.subscribeToOrder(
      orderId: orderId,
      token: token,
    );
  }

  void _setCustomerLocationFromOrder(Map<String, dynamic> raw) {
    LatLng? location;

    if (_order?.address?.latitude != null && _order?.address?.longitude != null) {
      final lat = double.tryParse(_order!.address!.latitude!);
      final lng = double.tryParse(_order!.address!.longitude!);
      if (lat != null && lng != null) {
        location = LatLng(lat, lng);
      }
    }

    location ??= _readLatLng(
      _readMap(raw, const ['delivery_address', 'deliveryAddress', 'address']),
    );

    _customerLocation = location;
  }

  void _setDriverLocationFromPayload(Map<String, dynamic> raw) {
    final directLocation = _readMap(raw, const [
      'driver_location',
      'driverLocation',
      'delivery_location',
      'location',
    ]);

    LatLng? location = _readLatLng(directLocation);
    double heading = _readDouble(
          directLocation?['heading'] ?? directLocation?['bearing'],
        ) ??
        0;

    final driverMap = _readMap(raw, const ['driver', 'delivery', 'assignedDriver']);
    final latLngString =
        _readString(driverMap, const ['lat_lng', 'latLang', 'location']);
    if (location == null && latLngString != null) {
      location = _parseLatLngPair(latLngString);
    }

    if (location != null) {
      _driverLocation = location;
      _driverHeading = heading;
    }
  }

  void _setDriverData(Map<String, dynamic> raw) {
    final driverMap = _readMap(raw, const ['driver', 'delivery', 'assignedDriver']);
    final vehicleMap = _readMap(
      driverMap,
      const ['vehicle', 'car', 'truck'],
    ) ??
        _readMap(raw, const ['vehicle']);

    _driverName = _readString(driverMap, const ['name', 'full_name', 'fullName']) ??
        _readString(raw, const ['delivery_name', 'driver_name']) ??
        _driverName;

    _driverRating = _readDouble(
      driverMap?['rating'] ?? driverMap?['score'] ?? raw['driver_rating'],
    );

    final vehicleModel = _readString(vehicleMap, const ['model', 'name', 'type']) ?? '';
    final vehicleColor = _readString(vehicleMap, const ['color']) ?? '';
    final formattedVehicle = [vehicleModel, vehicleColor]
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
    _vehicleName = formattedVehicle.isEmpty
        ? (_readString(raw, const ['vehicle_name']) ?? _vehicleName)
        : formattedVehicle;

    _vehiclePlate = _readString(vehicleMap, const [
          'plate',
          'license_plate',
          'licensePlate',
        ]) ??
        _readString(raw, const ['vehicle_plate', 'plate']) ??
        _vehiclePlate;

    _driverPhone = _readString(driverMap, const [
      'phone',
      'phone_number',
      'mobile',
    ]) ??
        _readString(raw, const ['delivery_phone', 'driver_phone']);

    _driverAvatarUrl = _readString(driverMap, const [
      'avatar',
      'photo',
      'selfie',
      'image',
    ]);
  }

  void _setEtaFromPayload(Map<String, dynamic> raw) {
    _etaMinutes = _readInt(raw['eta_minutes'] ?? raw['etaMinutes']);

    final etaString = _readString(raw, const [
      'estimated_arrival',
      'estimatedArrival',
      'eta_time',
      'etaTime',
    ]);
    if (etaString != null) {
      _etaDateTime = DateTime.tryParse(etaString);
    }

    if (_etaDateTime == null && _etaMinutes != null) {
      _etaDateTime = DateTime.now().add(Duration(minutes: _etaMinutes!));
    }
  }

  void _setStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      return;
    }

    _status = _normalizeStatus(status);
  }

  void _updateEtaFromDistance() {
    final distance = _distanceToCustomer;
    if (distance == null) {
      return;
    }

    if (distance < 200) {
      _etaMinutes = 0;
      _etaDateTime = DateTime.now();
      if (!_arrivingNotified) {
        _arrivingNotified = true;
      }
      return;
    }

    final minutes = max(1, ((distance / 1000) / 18 * 60).round());
    _etaMinutes = minutes;
    _etaDateTime = DateTime.now().add(Duration(minutes: minutes));
  }

  void _updateRoute({bool force = false}) {
    if (_customerLocation == null || _driverLocation == null) {
      return;
    }

    if (_routePoints.isEmpty || force || _lastRouteOrigin == null) {
      _routePoints
        ..clear()
        ..addAll([_driverLocation!, _customerLocation!]);
      _lastRouteOrigin = _driverLocation;
      return;
    }

    final movedDistance = Geolocator.distanceBetween(
      _lastRouteOrigin!.latitude,
      _lastRouteOrigin!.longitude,
      _driverLocation!.latitude,
      _driverLocation!.longitude,
    );

    if (movedDistance > 250) {
      _routePoints
        ..clear()
        ..addAll([_driverLocation!, _customerLocation!]);
      _lastRouteOrigin = _driverLocation;
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
    if (!showRadar) {
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

  String _normalizeStatus(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'assigned':
        return 'accepted';
      case 'in_progress':
      case 'in-progress':
      case 'on_the_way':
      case 'in_route':
      case 'out_for_delivery':
      case 'outfordelivery':
        return 'out_for_delivery';
      case 'arriving':
        return 'arriving';
      default:
        return rawStatus.trim().toLowerCase();
    }
  }

  String _driverFirstName() {
    final trimmed = _driverName.trim();
    if (trimmed.isEmpty) {
      return 'El chofer';
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
    return Geolocator.distanceBetween(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
      _customerLocation!.latitude,
      _customerLocation!.longitude,
    );
  }

  LatLng? _readLatLng(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }

    final lat = _readDouble(map['lat'] ?? map['latitude']);
    final lng = _readDouble(map['lng'] ?? map['longitude']);
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  LatLng? _parseLatLngPair(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) {
      return null;
    }
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
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

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _orderStatusSubscription?.cancel();
    _trackingService.disconnect();
    super.dispose();
  }
}
