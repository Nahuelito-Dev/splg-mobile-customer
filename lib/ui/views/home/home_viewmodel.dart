import 'package:splg_customer/ui/views/cart/cart_viewmodel.dart';
import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_lib/domain/order.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/domain/express_preview.dart';
import 'package:splg_customer/domain/reserved_orders.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_events_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/repurchase_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';
import 'package:splg_customer/ui/bottom_sheets/address_list/address_list_sheet_model.dart';
import 'package:splg_customer/ui/common/catalog_photos.dart';

/// Inicio: catálogo de garrafas, carrito y el pedido en curso. El menú lateral
/// y las demás pantallas salen de acá.
class HomeViewModel extends ReactiveViewModel
    with WidgetsBindingObserver, CatalogPhotos {
  /// [pollInterval] sólo se cambia en los tests.
  HomeViewModel({this.pollInterval = const Duration(seconds: 10)});

  final Duration pollInterval;

  final _cartService = locator<CartService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _gasCylinderService = locator<GasCylinderService>();
  final _historyService = locator<HistoryService>();
  final _dialogService = locator<DialogService>();
  final _locationService = locator<LocationService>();
  final _repurchaseService = locator<RepurchaseService>();
  final _events = locator<CustomerEventsService>();
  final _mercadoPago = locator<MercadoPagoCheckoutService>();
  final _notificationService = locator<NotificationService>();

  StreamSubscription<RepurchaseInvitationEvent>? _invitationSubscription;
  StreamSubscription<RepurchaseClosedEvent>? _closedSubscription;

  Timer? _poll;
  bool _closed = false;
  bool _inBackground = false;
  bool _stopped = false;
  Address? _chosenAddress;

  List<GasCylinder> _cylinders = [];
  List<GasCylinder> get cylinders => _cylinders;

  /// Texto de error si no se pudo cargar el catálogo.
  String? loadError;

  /// Por qué no se pudo traer el carrito al abrir (sin conexión, sesión...).
  String? cartError;

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
      // El carrito es el del back: al abrir la app se trae.
      final cart = await _cartService.refresh();
      cartError = cart.ok ? null : cart.message;
      await _applyPendingSelection();
      await _startRepurchase();
    }
    if (_closed) return;
    setBusy(false);
    _schedulePoll();
  }

  // ─── Recompra anticipada (M3) ───
  /// Invitación abierta a reponer, con el pedido precargado; null si no hay
  /// (con el módulo apagado nunca la hay).
  RepurchaseInvitation? invitation;

  /// Aceptando o descartando: la tarjeta no admite otro toque.
  bool repurchaseBusy = false;

  /// La tarjeta se muestra con una invitación abierta y vigente.
  bool get showRepurchase {
    final i = invitation;
    return !isBusy && i != null && i.isOpenAt(DateTime.now());
  }

  /// Engancha los avisos en vivo y lee la invitación. Todo es de apoyo: si
  /// falla, el Inicio sigue sin tarjeta.
  Future<void> _startRepurchase() async {
    _invitationSubscription ??=
        _events.repurchaseInvitations.listen((_) => refreshInvitation());
    _closedSubscription ??= _events.repurchaseClosed.listen(_onInvitationClosed);
    _events.connect();
    await refreshInvitation();
  }

  /// Vuelve a leer la invitación abierta en silencio.
  Future<void> refreshInvitation() async {
    if (_closed || !_customerService.isUserLoggedIn) return;
    final r = await _repurchaseService.openInvitations();
    if (_closed || !r.ok) return;
    final now = DateTime.now();
    final next = r.data!.where((i) => i.isOpenAt(now)).firstOrNull;
    // Otra invitación arranca con la dirección del inicio.
    if (next?.invitationId != invitation?.invitationId) {
      _repurchaseChoice = null;
    }
    invitation = next;
    _syncRepurchaseQuote();
    rebuildUi();
  }

  void _onInvitationClosed(RepurchaseClosedEvent event) {
    final current = invitation;
    if (current == null) return;
    if (event.invitationId != null &&
        event.invitationId != current.invitationId) {
      return;
    }
    invitation = null;
    if (!_closed) rebuildUi();
  }

  /// Dirección que el cliente eligió desde la tarjeta («Cambiar»).
  Address? _repurchaseChoice;

  /// Con qué dirección se pide la recompra: la elegida en la tarjeta o, si no,
  /// la de entrega del inicio; null si no tiene ninguna vigente (entonces el
  /// back usa la de la invitación).
  Address? get repurchaseAddress =>
      _current(_repurchaseChoice) ?? deliveryAddress;

  /// Lo que muestra la tarjeta: la misma dirección con la que se pide.
  String? get repurchaseAddressLabel {
    final a = repurchaseAddress;
    if (a == null) return invitation?.addressLabel;
    final formatted = a.formattedAddress?.trim();
    if (formatted != null && formatted.isNotEmpty) return formatted;
    return [a.streetName, a.city]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// El `addressId` que viaja al aceptar; null si es la de la invitación.
  String? get repurchaseAddressId {
    final a = repurchaseAddress;
    if (a == null || a.addressId == invitation?.addressId) return null;
    return a.addressId;
  }

  /// «Cambiar» en la tarjeta: el mismo selector de «Entregar en». Sólo cambia
  /// la dirección de la recompra, no la del inicio ni la del carrito.
  Future<void> changeRepurchaseAddress() async {
    if (invitation == null || repurchaseBusy) return;
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Elegí dónde te lo llevamos',
      data: {'selectedId': repurchaseAddress?.addressId},
    );
    if (_closed) return;
    if (response?.data == AddressListSheetModel.addNew) {
      final created = await _navigationService.navigateToAddressFormView();
      if (_closed || created is! Address) return;
      _repurchaseChoice = _current(created) ?? created;
    } else if (response?.confirmed == true && response?.data is Address) {
      _repurchaseChoice = response!.data as Address;
    } else {
      return;
    }
    _syncRepurchaseQuote();
    rebuildUi();
  }

  // Cotización con otra dirección: el total de la invitación vale para la
  // suya; con otra lo vuelve a calcular el back (`POST /orders/quote`).
  String? _quotedKey;
  bool _quoting = false;

  /// Cada cambio de dirección (y cada «Reintentar») es un intento nuevo; sólo
  /// se aplica la respuesta del último. La dirección sola no alcanza: A → B →
  /// A deja dos pedidos de A en vuelo y el viejo podría llegar último.
  int _quoteGeneration = 0;
  OrderQuote? _repurchaseQuote;

  /// Por qué no se pudo cotizar con la dirección elegida (fuera de cobertura,
  /// no es suya…), con el texto del back; con esto no se puede pedir.
  String? repurchaseQuoteError;

  /// La cotización falló por la red, un 429 o un 5xx: volver a pedirla puede
  /// andar («Reintentar»). Un 400/404 es definitivo para esa dirección.
  bool repurchaseQuoteRetryable = false;

  /// Cotiza si la dirección de la recompra cambió y no es la de la invitación.
  /// La respuesta sólo cuenta si sigue siendo la de esa dirección.
  void _syncRepurchaseQuote() {
    final current = invitation;
    final addressId = repurchaseAddressId;
    final key = current == null || addressId == null
        ? null
        : '${current.invitationId}:$addressId';
    if (key == _quotedKey) return;
    _quotedKey = key;
    final generation = ++_quoteGeneration;
    _repurchaseQuote = null;
    repurchaseQuoteError = null;
    repurchaseQuoteRetryable = false;
    _quoting = key != null;
    if (current == null || addressId == null) return;
    unawaited(() async {
      final r = await _repurchaseService.quote(current, addressId);
      if (_closed || generation != _quoteGeneration) return;
      _quoting = false;
      if (r.ok) {
        _repurchaseQuote = r.data;
      } else {
        repurchaseQuoteError = r.message;
        repurchaseQuoteRetryable = ApiErrorText.isRetryable(r.status);
      }
      rebuildUi();
    }());
  }

  /// «Reintentar»: vuelve a cotizar la misma dirección.
  void retryRepurchaseQuote() {
    if (!repurchaseQuoteRetryable) return;
    _quotedKey = null;
    _syncRepurchaseQuote();
    rebuildUi();
  }

  /// «Total aproximado …» con la dirección que muestra la tarjeta: el de la
  /// invitación si es la suya, el cotizado si es otra; «Calculando…» mientras
  /// llega y null si no se pudo cotizar.
  String? get repurchaseTotalText {
    final current = invitation;
    if (current == null) return null;
    if (repurchaseAddressId == null) {
      return 'Total aproximado ${money.format(current.estimatedTotal)}';
    }
    final quote = _repurchaseQuote;
    if (quote != null) return 'Total aproximado ${money.format(quote.total)}';
    if (_quoting) return 'Calculando…';
    return null;
  }

  /// «Pedir» habilitado: hay stock y, con otra dirección, ya está cotizada.
  bool get canAcceptRepurchase {
    final current = invitation;
    if (current == null || repurchaseBusy || current.hasUnavailable) {
      return false;
    }
    return repurchaseAddressId == null || _repurchaseQuote != null;
  }

  /// «Pedir»: el back crea el pedido con lo precargado, en la dirección que
  /// muestra la tarjeta, y se sigue al seguimiento. Un rechazo se muestra tal
  /// cual; nunca se da por hecho.
  Future<void> acceptInvitation() async {
    final current = invitation;
    if (current == null || repurchaseBusy) return;
    if (current.hasUnavailable) {
      await _dialogService.showDialog(
        title: 'Algo ya no está disponible',
        description: 'Alguna de tus garrafas habituales no tiene stock. '
            'Armá tu pedido desde el catálogo.',
        buttonTitle: 'Aceptar',
      );
      return;
    }
    // Con otra dirección sin cotizar (cargando o rechazada) no se pide.
    if (!canAcceptRepurchase) return;
    repurchaseBusy = true;
    rebuildUi();
    final r = await _repurchaseService.accept(current.invitationId,
        addressId: repurchaseAddressId);
    repurchaseBusy = false;
    if (_closed) return;
    if (!r.ok) {
      // 409: ya se resolvió o venció; deja de ofrecerse. 404: la dirección ya
      // no es suya (se borró en otro lado): se releen y la tarjeta queda para
      // elegir otra. Fuera de cobertura (400) también queda.
      if (r.status == 409) invitation = null;
      if (r.status == 404) unawaited(_refreshAddressesQuietly());
      rebuildUi();
      await _dialogService.showDialog(
        title: 'No pudimos crear tu pedido',
        description: r.message,
        buttonTitle: 'Aceptar',
      );
      return;
    }
    invitation = null;
    rebuildUi();
    final accepted = r.data!;
    await _historyService.tryRefreshHistory(limit: 10);
    final paymentUrl = accepted.paymentUrl;
    if (paymentUrl != null && paymentUrl.isNotEmpty) {
      await _mercadoPago.open(paymentUrl);
    }
    if (_closed) return;
    await _navigationService.navigateToOrderTrackingView(
        orderId: accepted.orderId);
  }

  /// Relee las direcciones sin cortar nada si falla.
  Future<void> _refreshAddressesQuietly() async {
    try {
      await _customerService.refreshAddresses();
    } catch (_) {}
    if (!_closed) rebuildUi();
  }

  /// «Ahora no»: descarta la invitación.
  Future<void> dismissInvitation() async {
    final current = invitation;
    if (current == null || repurchaseBusy) return;
    repurchaseBusy = true;
    rebuildUi();
    final r = await _repurchaseService.dismiss(current.invitationId);
    repurchaseBusy = false;
    if (_closed) return;
    if (r.ok || r.status == 409) invitation = null;
    rebuildUi();
    if (!r.ok && r.status != 409) {
      await _dialogService.showDialog(
        title: 'No pudimos descartar el aviso',
        description: r.message,
        buttonTitle: 'Aceptar',
      );
    }
  }

  /// Lo que eligió en el catálogo público antes de iniciar sesión pasa al
  /// carrito del back. Si alguna no se pudo (tipo dado de baja, tope), se
  /// avisa y el resto queda.
  Future<void> _applyPendingSelection() async {
    final pending = _gasCylinderService.takePendingSelection();
    String? failure;
    for (final entry in pending.entries) {
      final result = await _cartService.add(entry.key, entry.value);
      if (!result.ok) failure ??= result.message;
    }
    if (failure != null && !_closed) {
      await _dialogService.showDialog(
        title: 'No pudimos sumar todo al carrito',
        description: failure,
        buttonTitle: 'Aceptar',
      );
    }
  }

  /// La tira de garrafas a la vista del inicio: sólo con catálogo cargado.
  bool get showFeatured =>
      !isBusy && loadError == null && _cylinders.isNotEmpty;

  /// Tocar una garrafa de la tira la suma al carrito (la hoja del catálogo
  /// se abre desde la vista y se repinta sola cuando el back responde).
  Future<void> addFeatured(GasCylinder cylinder) => addItem(cylinder, 1);

  @override
  GasCylinderService get catalogPhotoService => _gasCylinderService;

  /// Si las URLs firmadas de las fotos vencieron, vuelve a pedir el catálogo en
  /// silencio (sin loader) para renovarlas.
  Future<void> renewCatalogPhotos() async {
    if (isBusy) return;
    if (await _gasCylinderService.renewPhotos() && !_closed) {
      notifyListeners();
    }
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
      final i = invitation;
      if (i != null && !i.isOpenAt(DateTime.now()) && !_closed) {
        invitation = null;
        rebuildUi();
      }
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
      _events.disconnect();
    } else if (!_closed) {
      _stopped = false;
      // Al volver se pone al día enseguida y retoma el ritmo.
      _historyService.tryRefreshHistory(limit: 10).then((_) => _schedulePoll());
      if (_customerService.isUserLoggedIn) unawaited(_startRepurchase());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _customerService.removeListener(reconcileAddress);
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();
    _invitationSubscription?.cancel();
    _closedSubscription?.cancel();
    _events.disconnect();
    super.dispose();
  }

  // ─── Pedido en curso ───
  Order? get _activeOrder {
    for (final order in _historyService.history) {
      // La reserva con seña todavía no busca repartidor.
      if (ReservedOrders.contains(order.id)) continue;
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

  // ─── Compra express de un toque (CU-147) ───
  // Con la dirección predeterminada y la garrafa habitual el back arma la vista
  // previa con el precio final; el cliente confirma y el pedido sale al chofer
  // en moto más cercano. Se paga en efectivo al recibir; con otro medio de pago
  // se usa el pedido común.

  bool _expressBusy = false;
  bool get expressBusy => _expressBusy;

  Future<void> expressOrder() async {
    if (_expressBusy) return;
    if (!_customerService.isUserLoggedIn) {
      await _navigationService.navigateToLoginView();
      return;
    }
    _expressBusy = true;
    rebuildUi();
    try {
      await _runExpress();
    } finally {
      _expressBusy = false;
      if (!_closed) rebuildUi();
    }
  }

  Future<void> _runExpress() async {
    const method = PaymentMethod.cash;
    final preview = await _historyService.expressPreview(paymentMethod: method);
    if (_closed) return;
    final data = preview.data;
    if (!preview.ok || data == null) {
      await _dialogService.showDialog(
        title: 'No pudimos preparar tu pedido express',
        description: preview.message,
        buttonTitle: 'Aceptar',
      );
      return;
    }
    if (!data.available || data.quote == null) {
      await _dialogService.showDialog(
        title: 'El express no está disponible',
        description: '${data.unavailableText}\n\nPodés pedir con el reparto '
            'común y elegir una franja de entrega.',
        buttonTitle: 'Aceptar',
      );
      return;
    }
    final confirm = await _dialogService.showConfirmationDialog(
      title: 'Pedido express',
      description: _expressSummary(data),
      confirmationTitle: 'Pedir ahora',
      cancelTitle: 'Cancelar',
    );
    if (_closed || confirm?.confirmed != true) return;

    final result = await _historyService.expressBuy(
      paymentMethod: method,
      gasCylinderId: data.gasCylinderId,
      quantity: data.quantity,
    );
    if (_closed) return;
    if (result.success) {
      unawaited(_notificationService.requestPermissionAndRegister());
      final id = result.order?.id;
      if (id != null) {
        await _navigationService.navigateToOrderTrackingView(orderId: id);
      }
      return;
    }
    await _dialogService.showDialog(
      title: result.idempotencyConflict
          ? 'Revisá Mis pedidos'
          : result.expressUnavailableReason != null
              ? 'El express ya no está disponible'
              : 'No pudimos crear tu pedido',
      description: result.message,
      buttonTitle: 'Aceptar',
    );
  }

  /// Qué se compra, adónde llega, cuánto sale y en cuánto tiempo.
  String _expressSummary(ExpressPreview p) {
    GasCylinder? cylinder;
    for (final c in _cylinders) {
      if (c.id == p.gasCylinderId) cylinder = c;
    }
    final what = cylinder == null || cylinder.type.trim().isEmpty
        ? 'Garrafa'
        : cylinder.type.trim();
    final quote = p.quote!;
    final surcharge = quote.expressSurcharge > 0
        ? ' (incluye ${money.format(quote.expressSurcharge)} de recargo express)'
        : '';
    final containers = quote.chargesContainers
        ? ' Incluye ${money.format(quote.containerChargeAmount)} de envases.'
        : '';
    return [
      '${p.quantity}x $what',
      if ((p.addressText ?? '').isNotEmpty) 'Entrega en ${p.addressText}',
      'Total: ${money.format(quote.total)}$surcharge.$containers',
      if (p.estimatedMinutes != null) 'Llega en ~${p.estimatedMinutes} min',
      'Pagás en efectivo al recibir.',
    ].join('\n');
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

  /// El aviso se arregla desde los Ajustes del teléfono (GPS apagado o sin
  /// respuesta); no cuando el back rechazó guardar la ubicación.
  bool locationSettingsHint = true;

  static const locateTimeout = Duration(seconds: 15);

  /// "Mi ubicación": recién acá se pide el permiso. Sin permiso no pasa nada
  /// más que lo que muestra el servicio de permisos; con el GPS apagado se
  /// avisa y se ofrece ir a Ajustes. Un segundo toque mientras busca no hace nada.
  Future<void> locateMe() async {
    if (_locating) return;
    _locating = true;
    locationNotice = null;
    locationSettingsHint = true;
    try {
      final p =
          await _locationService.getCurrentPosition().timeout(locateTimeout);
      if (_closed) return;
      userPoint = LatLng(p.latitude, p.longitude);
      showUserLocation = true;
      // CU-094: la posición que el cliente pidió ver queda como su ubicación de
      // referencia. Si el back la rechaza se avisa con su texto.
      if (_customerService.isUserLoggedIn) {
        final saved =
            await _customerService.updateLocation(p.latitude, p.longitude);
        if (_closed) return;
        if (!saved.ok) {
          log('No se guardó la ubicación: ${saved.status}');
          locationNotice = 'No pudimos guardar tu ubicación. '
              '${saved.message ?? ApiErrorText.generic}';
          locationSettingsHint = false;
        }
      }
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
      _current(_cartService.address) ??
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
    final wasId = _cartService.address?.addressId ?? _chosenAddress?.addressId;
    final resolved = deliveryAddress;
    if (wasId != null && resolved?.addressId != wasId) {
      addressNotice = resolved == null
          ? 'La dirección que habías elegido ya no existe. Elegí otra.'
          : 'La dirección que habías elegido ya no existe. Usamos ${resolved.streetName}.';
    }
    _chosenAddress = resolved;
    _syncCartAddress(resolved);
    _syncRepurchaseQuote();
    rebuildUi();
  }

  void _syncCartAddress(Address? address) {
    if (_cartService.address == address) return;
    _cartService.setAddress(address);
  }

  void _choose(Address address) {
    _chosenAddress = address;
    addressNotice = null;
    _syncCartAddress(address);
    _syncRepurchaseQuote();
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

  // ─── Carrito (el del back) ───
  int getItemQuantity(String cylinderId) => _cartService.quantityOf(cylinderId);

  /// Suma o resta una unidad del tipo en el carrito del back. Sin sesión no hay
  /// carrito: lleva al login. Un rechazo del back (tope, tipo dado de baja, sin
  /// conexión) se muestra; nunca se da por hecho el cambio.
  Future<void> addItem(GasCylinder cylinder, int quantity) async {
    if (quantity == 0) return;
    if (!_customerService.isUserLoggedIn) {
      await _navigationService.navigateToLoginView();
      return;
    }
    final result = quantity > 0
        ? await _cartService.add(cylinder.id, quantity)
        : await _cartService.removeOne(cylinder.id);
    if (result.ok || _closed) return;
    await _dialogService.showDialog(
      title: 'No pudimos actualizar el carrito',
      description: result.message,
      buttonTitle: 'Aceptar',
    );
  }

  int get itemCount => _cartService.itemCount;

  /// Texto del botón que sigue al carrito. No lleva precio: el total (con
  /// promociones, zona y medio de pago) lo cotiza el back en la confirmación.
  String get continueLabel =>
      'Continuar · $itemCount ${itemCount == 1 ? 'garrafa' : 'garrafas'}';

  bool get canPlaceOrder => itemCount > 0;

  /// El carrito pidió volver con el catálogo abierto ([CartViewModel.addMore]).
  bool catalogRequested = false;

  Future<void> placeOrder() async {
    if (!canPlaceOrder) return;

    if (_customerService.isUserLoggedIn) {
      final result = await _navigationService.navigateToCartView();
      if (result == CartViewModel.addMoreResult) {
        catalogRequested = true;
        notifyListeners();
      }
    } else {
      _navigationService.navigateToLoginView();
    }
  }

  /// La vista abre el catálogo una sola vez por pedido del carrito.
  bool takeCatalogRequest() {
    final pedido = catalogRequested;
    catalogRequested = false;
    return pedido;
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [
        _cartService,
        _historyService,
      ];
}
