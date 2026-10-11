import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/ui/bottom_sheets/address_list/address_list_sheet_model.dart';

/// Inicio: catálogo de garrafas, carrito y el pedido en curso. El menú lateral
/// y las demás pantallas salen de acá.
class HomeViewModel extends ReactiveViewModel with WidgetsBindingObserver {
  /// [pollInterval] sólo se cambia en los tests.
  HomeViewModel({this.pollInterval = const Duration(seconds: 10)});

  final Duration pollInterval;

  final _cartService = locator<CartService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _gasCylinderService = locator<GasCylinderService>();
  final _historyService = locator<HistoryService>();
  final _locationService = locator<LocationService>();

  Timer? _poll;
  bool _closed = false;
  bool _inBackground = false;
  bool _stopped = false;
  Address? _chosenAddress;

  List<GasCylinder> _cylinders = [];
  List<GasCylinder> get cylinders => _cylinders;

  /// Texto de error si no se pudo cargar el catálogo.
  String? loadError;

  /// El polling está programado (hay un `Timer` pendiente o una consulta en
  /// curso). Para los tests.
  @visibleForTesting
  bool get isPolling => _poll != null;

  Future<void> initialize() async {
    if (_closed) return;
    _stopped = false;
    _customerService
      ..removeListener(reconcileAddress)
      ..addListener(reconcileAddress);
    WidgetsBinding.instance
      ..removeObserver(this)
      ..addObserver(this);
    setBusy(true);
    loadError = null;
    try {
      await _loadCylinders();
    } catch (_) {
      loadError = _catalogError;
    }
    // El resto es de apoyo: si falla se queda con lo que ya había.
    await _historyService.tryRefreshHistory(limit: 10);
    if (_customerService.isUserLoggedIn) {
      try {
        await _customerService.refreshAddresses();
      } catch (_) {}
    }
    if (_closed) return;
    setBusy(false);
    _schedulePoll();
  }

  String? cylinderPhoto(String id) => _gasCylinderService.photoUrl(id);

  /// Si las URLs firmadas de las fotos vencieron, vuelve a pedir el catálogo en
  /// silencio (sin loader) para renovarlas.
  Future<void> renewCatalogPhotos() async {
    if (isBusy || !_gasCylinderService.hasExpiredPhotos) return;
    try {
      await _loadCylinders();
      if (!_closed) notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadCylinders() async {
    _cylinders = await _gasCylinderService.getGasCylinders();
  }

  /// Vuelve a pedir sólo el catálogo (reintento y apertura de "¿Qué necesitás?"
  /// cuando la carga falló).
  Future<void> reloadCatalog() async {
    if (isBusy) return;
    setBusy(true);
    loadError = null;
    try {
      await _loadCylinders();
    } catch (_) {
      loadError = _catalogError;
    }
    if (_closed) return;
    setBusy(false);
  }

  static const _catalogError =
      'No pudimos cargar las garrafas. Probá de nuevo.';

  /// Programa la próxima consulta recién cuando termina la anterior (no se
  /// solapan) y sólo si la pantalla sigue abierta y la app en primer plano.
  void _schedulePoll() {
    _poll?.cancel();
    if (_closed || _inBackground || _stopped) {
      _poll = null;
      return;
    }
    _poll = Timer(pollInterval, () async {
      await _historyService.tryRefreshHistory(limit: 10);
      _schedulePoll();
    });
  }

  /// Corta el polling (cierre de sesión).
  void stopPolling() {
    _stopped = true;
    _poll?.cancel();
    _poll = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state != AppLifecycleState.resumed;
    if (background == _inBackground) return;
    _inBackground = background;
    if (background) {
      stopPolling();
    } else if (!_closed) {
      _stopped = false;
      // Al volver se pone al día enseguida y retoma el ritmo.
      _historyService.tryRefreshHistory(limit: 10).then((_) => _schedulePoll());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _customerService.removeListener(reconcileAddress);
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();
    super.dispose();
  }

  // ─── Pedido en curso ───
  Order? get _activeOrder {
    for (final order in _historyService.history) {
      if (order.status == OrderStatus.pending ||
          order.status == OrderStatus.accepted ||
          order.status == OrderStatus.outForDelivery) {
        return order;
      }
    }
    return null;
  }

  bool get hasActiveOrder => _activeOrder != null;

  String get activeOrderId => _activeOrder?.id ?? '';

  String get activeOrderStatusLabel => switch (_activeOrder?.status) {
        OrderStatus.pending => 'Buscando repartidor',
        OrderStatus.accepted => 'Repartidor asignado',
        OrderStatus.outForDelivery => 'Tu pedido está en camino',
        _ => '',
      };

  String get activeOrderShortCode {
    final id = activeOrderId;
    return id.length > 6 ? id.substring(id.length - 6) : id;
  }

  Future<void> openActiveOrder() async {
    if (!hasActiveOrder) return;
    await _navigationService.navigateToOrderTrackingView(
        orderId: activeOrderId);
  }

  // ─── Mapa ───
  /// Punto de la dirección de entrega elegida (null si no tiene coordenadas).
  LatLng? get deliveryPoint {
    final a = deliveryAddress;
    final lat = double.tryParse(a?.latitude ?? '');
    final lng = double.tryParse(a?.longitude ?? '');
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  LatLng? userPoint;
  bool showUserLocation = false;
  bool _locating = false;

  /// Aviso bajo el mapa cuando "Mi ubicación" no se pudo (GPS apagado).
  String? locationNotice;

  static const locateTimeout = Duration(seconds: 15);

  /// "Mi ubicación": recién acá se pide el permiso. Sin permiso no pasa nada
  /// más que lo que muestra el servicio de permisos; con el GPS apagado se
  /// avisa y se ofrece ir a Ajustes. Un segundo toque mientras busca no hace nada.
  Future<void> locateMe() async {
    if (_locating) return;
    _locating = true;
    locationNotice = null;
    try {
      final p =
          await _locationService.getCurrentPosition().timeout(locateTimeout);
      if (_closed) return;
      userPoint = LatLng(p.latitude, p.longitude);
      showUserLocation = true;
    } on LocationUnavailableException catch (e) {
      if (e.serviceDisabled) {
        locationNotice =
            'Activá la ubicación del teléfono para ver dónde estás.';
      }
    } on TimeoutException {
      locationNotice = 'No pudimos ubicarte. Probá de nuevo en un momento.';
    } catch (_) {
      locationNotice = 'No pudimos ubicarte. Probá de nuevo en un momento.';
    } finally {
      _locating = false;
    }
    if (!_closed) rebuildUi();
  }

  Future<void> openLocationSettings() =>
      _locationService.openLocationSettings();

  void dismissLocationNotice() {
    locationNotice = null;
    rebuildUi();
  }

  Future<void> openOrders() => _navigationService.navigateToOrdersView();

  // ─── Dirección de entrega ───
  /// La dirección vigente en `customer.addresses` con ese id (con los datos
  /// actuales, si se editó), o null si ya no existe.
  Address? _current(Address? a) {
    if (a == null) return null;
    for (final s in _customerService.customer.addresses) {
      if (s.addressId == a.addressId) return s;
    }
    return null;
  }

  Address? get _fallbackAddress {
    final saved = _customerService.customer.addresses;
    if (saved.isEmpty) return null;
    return saved.firstWhere((a) => a.primary, orElse: () => saved.first);
  }

  /// Elegida en el carrito o en la hoja, siempre contra las direcciones
  /// vigentes; sin una válida, la predeterminada (o ninguna).
  Address? get deliveryAddress =>
      _current(_cartService.order?.address) ??
      _current(_chosenAddress) ??
      _fallbackAddress;

  /// Explica por qué cambió la dirección elegida (se borró).
  String? addressNotice;

  String get deliveryLabel {
    final a = deliveryAddress;
    if (a == null) return 'Elegí tu dirección de entrega';
    return 'Entregar en: ${a.streetName}';
  }

  /// Las direcciones cambiaron (se borró, editó o creó una): si la elegida ya no
  /// existe vuelve a la predeterminada con aviso; si se editó, toma los datos
  /// nuevos; el carrito sigue lo que muestra la píldora.
  void reconcileAddress() {
    if (_closed) return;
    final wasId =
        _cartService.order?.address?.addressId ?? _chosenAddress?.addressId;
    final resolved = deliveryAddress;
    if (wasId != null && resolved?.addressId != wasId) {
      addressNotice = resolved == null
          ? 'La dirección que habías elegido ya no existe. Elegí otra.'
          : 'La dirección que habías elegido ya no existe. Usamos ${resolved.streetName}.';
    }
    _chosenAddress = resolved;
    _syncCartAddress(resolved);
    rebuildUi();
  }

  void _syncCartAddress(Address? address) {
    final order = _cartService.order;
    if (order == null || order.address == address) return;
    _cartService.setOrder(order.copyWith(address: address));
  }

  void _choose(Address address) {
    _chosenAddress = address;
    addressNotice = null;
    _syncCartAddress(address);
    rebuildUi();
  }

  Future<void> chooseAddress() async {
    if (!_customerService.isUserLoggedIn) {
      await _navigationService.navigateToLoginView();
      return;
    }
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Elegí una dirección',
      data: {'selectedId': deliveryAddress?.addressId},
    );
    if (response?.data == AddressListSheetModel.addNew) {
      await addAddress();
      return;
    }
    if (response?.confirmed == true && response?.data is Address) {
      _choose(response!.data as Address);
    }
  }

  /// Alta de una dirección: el formulario devuelve la que creó y esa es la que
  /// queda elegida. Si se cancela, no cambia nada.
  Future<void> addAddress() async {
    final created = await _navigationService.navigateToAddressFormView();
    if (created is! Address) return;
    _choose(_current(created) ?? created);
  }

  // ─── Carrito ───
  int getItemQuantity(String cylinderId) {
    final order = _cartService.order;
    if (order == null) return 0;
    for (final item in order.items) {
      if (item.cylinder.id == cylinderId) return item.quantity;
    }
    return 0;
  }

  void addItem(GasCylinder cylinder, int quantity) {
    if (_cartService.order == null) _createOrder();

    final order = _cartService.order!;
    final current = getItemQuantity(cylinder.id);
    final newQty = current + quantity;
    final others =
        order.items.where((i) => i.cylinder.id != cylinder.id).toList();
    if (newQty > 0) {
      others.add(OrderItem(cylinder: cylinder, quantity: newQty));
    }
    _cartService.setOrder(order.copyWith(items: others));
  }

  void _createOrder() {
    _cartService.clearEditingOrder();
    _cartService.setOrder(Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      address: deliveryAddress,
      items: [],
      total: 0,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    ));
  }

  double get total => Pricing.total(_cartService.order?.items ?? const []);

  int get itemCount => (_cartService.order?.items ?? const <OrderItem>[])
      .fold(0, (n, i) => n + i.quantity);

  bool get canPlaceOrder => total > 0;

  void placeOrder() {
    if (!canPlaceOrder) return;

    if (_customerService.isUserLoggedIn) {
      _cartService.clearEditingOrder();
      _navigationService.navigateToCheckoutView();
    } else {
      _navigationService.navigateToLoginView();
    }
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [
        _cartService,
        _historyService,
      ];
}
