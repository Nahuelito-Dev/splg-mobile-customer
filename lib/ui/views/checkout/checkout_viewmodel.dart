import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/bottom_sheets/address_list/address_list_sheet_model.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/app/app.bottomsheets.dart';

class CheckoutViewModel extends ReactiveViewModel {
  final _cartService = locator<CartService>();
  final _historyService = locator<HistoryService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _dialogService = locator<DialogService>();
  final _timeSlotService = locator<TimeSlotService>();
  final _notificationService = locator<NotificationService>();

  Order? get order => _cartService.order;

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  PaymentMethod get selectedPaymentMethod => _selectedPaymentMethod;

  final TextEditingController addressController = TextEditingController();

  void initialize() {
    setBusy(true);
    // El carrito no lleva dirección: al llegar acá se toma la elegida, o la
    // predeterminada (o la primera) de las direcciones guardadas.
    var address = _cartService.address;
    final saved = _customerService.customer.addresses;
    if (address != null && saved.isNotEmpty) {
      // Si se borró o editó en otra pantalla, vale la vigente (o ninguna).
      address = _current(address);
      final current = address;
      if (current != null && current != _cartService.address) {
        Future.microtask(() => _setOrderAddress(current));
      }
    }
    if (address == null && saved.isNotEmpty) {
      address = saved.firstWhere((a) => a.primary, orElse: () => saved.first);
      // initialize() corre dentro del build: notificar al carrito ahí
      // dispara "setState durante build", así que se difiere.
      final selected = address;
      Future.microtask(() => _setOrderAddress(selected));
    }
    addressController.text = address?.streetName ?? '';
    _selectedPaymentMethod = PaymentMethod.cash;
    setBusy(false);
    // Trae las franjas de la fecha por defecto (hoy) para que el cliente elija.
    loadTimeSlots();
    loadDeliveryOptions();
    scheduleQuote();
  }

  void setPaymentMethod(PaymentMethod method) {
    // Mientras confirma, el pedido que sale es el que se cotizó.
    if (isBusy) return;
    _selectedPaymentMethod = method;
    paymentOpen = false;
    rebuildUi();
    scheduleQuote();
  }

  /// Desplegables de la confirmación.
  bool paymentOpen = false;
  bool slotsOpen = true;

  void togglePayment() {
    paymentOpen = !paymentOpen;
    rebuildUi();
  }

  void toggleSlots() {
    slotsOpen = !slotsOpen;
    rebuildUi();
  }

  /// Etiqueta de la franja elegida, o null.
  String? get selectedSlotLabel => _selectedSlot?.label;

  Future<void> showAddressList() async {
    if (isBusy) return;
    if (_customerService.customer.addresses.isEmpty) {
      await _addAddress();
      return;
    }
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Selecciona una dirección',
      data: {'selectedId': _cartService.address?.addressId},
    );

    if (response?.data == AddressListSheetModel.addNew) {
      await _addAddress();
    } else if (response?.confirmed == true && response?.data is Address) {
      final address = response!.data as Address;
      addressController.text = address.streetName;
      _setOrderAddress(address);
      rebuildUi();
    }
  }

  /// La dirección vigente con ese id en `customer.addresses`, o null si ya no
  /// existe.
  /// La cotización depende de la zona de cobertura: sale de dónde se entrega
  /// (calle, ciudad y coordenadas), no del texto armado ni de las indicaciones.
  @visibleForTesting
  static bool mueveElPrecio(Address antes, Address ahora) =>
      antes.addressId != ahora.addressId ||
      antes.streetName != ahora.streetName ||
      antes.city != ahora.city ||
      antes.latitude != ahora.latitude ||
      antes.longitude != ahora.longitude;

  bool _mueveElPrecio(Address antes, Address ahora) =>
      mueveElPrecio(antes, ahora);

  Address? _current(Address? a) {
    if (a == null) return null;
    for (final s in _customerService.customer.addresses) {
      if (s.addressId == a.addressId) return s;
    }
    return null;
  }

  /// Alta desde la hoja (o sin direcciones): el formulario devuelve la dirección
  /// creada y esa queda elegida. Si se cancela no cambia nada.
  Future<void> _addAddress() async {
    final created = await _navigationService.navigateToAddressFormView();
    if (created is! Address) return;
    final a = _current(created) ?? created;
    addressController.text = a.streetName;
    _setOrderAddress(a);
    rebuildUi();
  }

  void _setOrderAddress(Address address) {
    _cartService.setAddress(address);
    _deliveryNotice = null;
    loadDeliveryOptions();
    scheduleQuote();
  }

  // ─── Modalidad de entrega (CU-148) ───
  // Normal o express, con lo que ofrece la distribuidora para la dirección
  // (`GET /orders/delivery-options`): disponibilidad, recargo y por qué no. El
  // express no se agenda, así que sin fecha ni franja.

  DeliveryMode _mode = DeliveryMode.standard;
  DeliveryMode get deliveryMode => _mode;
  bool get isExpress => _mode == DeliveryMode.express;

  DeliveryOptions? _options;
  String? _optionsAddressId;
  String? _optionsInFlight;
  int _optionsVersion = 0;

  bool _loadingOptions = false;
  bool get loadingOptions => _loadingOptions;

  /// Aviso de por qué se volvió al reparto común (el express dejó de estar
  /// disponible); null si no hubo.
  String? _deliveryNotice;
  String? get deliveryNotice => _deliveryNotice;

  DeliveryOption? get standardOption =>
      _options?.optionFor(DeliveryMode.standard);
  DeliveryOption? get expressOption =>
      _options?.optionFor(DeliveryMode.express);

  /// Se ofrece elegir modalidad: la distribuidora tiene el express habilitado.
  /// Si lo apagó (`disabled`) o la consulta falló, no hay nada que elegir.
  bool get showDeliveryChoice {
    final express = expressOption;
    return express != null && express.reason != 'disabled';
  }

  /// Pide las modalidades de la dirección elegida. Una respuesta que llega
  /// vieja (se cambió la dirección mientras tanto) no pisa a la última. Si la
  /// consulta falla no se ofrece el express: el reparto común sigue andando.
  Future<void> loadDeliveryOptions({bool force = false}) async {
    final addressId = order?.address?.addressId;
    if (addressId == null || addressId.isEmpty) {
      _options = null;
      _optionsAddressId = null;
      _backToStandard();
      return;
    }
    if (!force &&
        (addressId == _optionsAddressId || addressId == _optionsInFlight)) {
      return;
    }
    final version = ++_optionsVersion;
    _optionsInFlight = addressId;
    _loadingOptions = true;
    if (!_disposed) notifyListeners();
    final result = await _historyService.deliveryOptions(addressId);
    if (_disposed || version != _optionsVersion) return;
    _optionsInFlight = null;
    _loadingOptions = false;
    _options = result.ok ? result.data : null;
    // Sólo cuenta como cargada si salió bien: una falla se reintenta.
    _optionsAddressId = result.ok ? addressId : null;
    if (expressOption?.available ?? false) _deliveryNotice = null;
    if (isExpress && !(expressOption?.available ?? false)) {
      _deliveryNotice = expressOption?.unavailableText ??
          'La entrega express no está disponible en este momento.';
      _backToStandard();
    }
    notifyListeners();
  }

  void _backToStandard() {
    if (_mode == DeliveryMode.standard) return;
    _mode = DeliveryMode.standard;
    scheduleQuote();
  }

  void setDeliveryMode(DeliveryMode mode) {
    if (isBusy || mode == _mode) return;
    if (mode == DeliveryMode.express && !(expressOption?.available ?? false)) {
      return;
    }
    _mode = mode;
    _deliveryNotice = null;
    notifyListeners();
    scheduleQuote();
  }

  // ─── Quién recibe (CU-128, opcional) ───

  OrderReceiver? _receiver;
  OrderReceiver? get receiver => _receiver;

  Future<void> editReceiver() async {
    if (isBusy) return;
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.receiver,
      isScrollControlled: true,
      enableDrag: false,
      data: {'receiver': _receiver},
    );
    if (response?.confirmed == true && response?.data is OrderReceiver) {
      _receiver = response!.data as OrderReceiver;
      rebuildUi();
    }
  }

  void clearReceiver() {
    if (isBusy) return;
    _receiver = null;
    rebuildUi();
  }

  // ─── Cotización (el precio lo calcula el back) ───
  // Promociones por volumen, recargo de zona y por medio de pago salen de
  // `POST /orders/quote`; la app muestra lo que devuelve. Se pide con debounce
  // cada vez que cambia algo que mueve el precio (dirección, medio de pago,
  // franja) y una respuesta que llega vieja no pisa a la última.

  /// Espera entre el último cambio y el pedido de cotización.
  @visibleForTesting
  static Duration quoteDebounce = const Duration(milliseconds: 400);

  OrderQuote? _quote;

  /// La cotización vigente, o null mientras se pide, si falló o si falta la
  /// dirección.
  OrderQuote? get quote => _quote;

  bool _quoting = false;
  bool get quoting => _quoting;

  String? _quoteError;
  bool _quoteRetryable = false;

  /// Por qué no hay total, con el texto listo para mostrar.
  String? get quoteError => _quoteError;

  /// Hay un error que pedir de nuevo puede arreglar (red, 429, 5xx).
  bool get canRetryQuote => _quoteError != null && _quoteRetryable;

  Timer? _quoteTimer;
  int _quoteVersion = 0;
  bool _disposed = false;

  void scheduleQuote({bool immediate = false}) {
    _quoteTimer?.cancel();
    final version = ++_quoteVersion;
    _quote = null;
    _quoteError = null;
    final current = order;
    if (current == null || current.items.isEmpty || current.address == null) {
      _quoting = false;
      if (!_disposed) notifyListeners();
      return;
    }
    _quoting = true;
    if (!_disposed) notifyListeners();
    _quoteTimer = Timer(
      immediate ? Duration.zero : quoteDebounce,
      () => _runQuote(version),
    );
  }

  void retryQuote() => scheduleQuote(immediate: true);

  Future<void> _runQuote(int version) async {
    final current = order;
    if (current == null) return;
    final outcome = await _historyService.quoteOrder(
      current.copyWith(
        requestedDeliveryDate: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
      ),
      timeSlotId: _selectedTimeSlotId,
      fromCart: true,
      deliveryMode: _mode,
    );
    if (_disposed || version != _quoteVersion) return;
    // El express dejó de estar disponible: se vuelve al reparto común con el
    // motivo a la vista y se cotiza de nuevo.
    if (outcome.expressUnavailableReason != null && isExpress) {
      _deliveryNotice = outcome.message;
      _backToStandard();
      unawaited(loadDeliveryOptions(force: true));
      return;
    }
    _quoting = false;
    _quote = outcome.quote;
    _quoteError = outcome.ok ? null : outcome.message;
    _quoteRetryable = outcome.retryable;
    notifyListeners();
  }

  // ─── Franjas horarias (agendamiento) ───
  // El backend agenda por franjas fijas con cupo diario (las administra el
  // panel), así que el cliente elige una franja disponible para la fecha, en
  // vez de un rango de horas libre.
  List<TimeSlotAvailability> _timeSlots = [];
  List<TimeSlotAvailability> get timeSlots => _timeSlots;

  bool _loadingTimeSlots = false;
  bool get loadingTimeSlots => _loadingTimeSlots;

  String? _selectedTimeSlotId;
  String? get selectedTimeSlotId => _selectedTimeSlotId;

  /// Trae las franjas disponibles para la fecha seleccionada. Si la franja
  /// elegida ya no está disponible (cambió la fecha o se llenó), la deselecciona.
  Future<void> loadTimeSlots() async {
    _loadingTimeSlots = true;
    notifyListeners();

    _timeSlots = await _timeSlotService.availabilityFor(_selectedDate);

    final stillValid = _timeSlots.any(
      (slot) => slot.timeSlotId == _selectedTimeSlotId && !slot.isFull,
    );
    if (!stillValid && _selectedTimeSlotId != null) {
      _selectedTimeSlotId = null;
      scheduleQuote();
    }

    _loadingTimeSlots = false;
    notifyListeners();
  }

  void selectTimeSlot(String timeSlotId) {
    if (isBusy) return;
    _selectedTimeSlotId = timeSlotId;
    notifyListeners();
    scheduleQuote();
  }

  TimeSlotAvailability? get _selectedSlot {
    for (final slot in _timeSlots) {
      if (slot.timeSlotId == _selectedTimeSlotId) return slot;
    }
    return null;
  }

  /// Lo que cobra el back por esta garrafa (con la promoción por volumen), o
  /// null mientras no hay cotización.
  QuoteLine? quoteLineFor(OrderItem item) => _quote?.lineFor(item.cylinder.id);

  bool get canConfirmOrder {
    return order != null &&
        order!.items.isNotEmpty &&
        !_cartService.cart.hasUnavailableItems &&
        addressController.text.isNotEmpty &&
        (isExpress || _selectedTimeSlotId != null) &&
        _quote != null;
  }

  /// Reloj del checkout; los tests lo fijan para que el golden no dependa del día.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  DateTime _selectedDate = now();
  DateTime get selectedDate => _selectedDate;

  String get formattedDate =>
      DateFormat('dd/MM/yyyy', 'es_AR').format(_selectedDate);

  Future<void> selectDate(BuildContext context) async {
    if (isBusy) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('es', 'AR'),
    );
    if (picked != null && picked != _selectedDate) {
      _selectedDate = picked;
      notifyListeners();
      // La disponibilidad de franjas depende del día → recargar.
      await loadTimeSlots();
      scheduleQuote();
    }
  }

  /// Antes de mandar el pedido: relee las direcciones (si no puede, usa las
  /// locales) y comprueba que la elegida siga existiendo. Si no, la saca del
  /// carrito y avisa.
  Future<bool> _addressStillValid() async {
    try {
      await _customerService.refreshAddresses();
    } catch (_) {}
    final chosen = _cartService.address;
    final current = _current(chosen);
    if (current != null) {
      // Sólo vuelve a cotizar si cambió algo que mueve el precio (dónde se
      // entrega). Releer la lista trae la misma dirección con otros datos
      // (texto, indicaciones): eso no invalida la cotización mostrada.
      if (_mueveElPrecio(chosen!, current)) {
        _setOrderAddress(current);
      } else if (current != chosen) {
        _cartService.setAddress(current);
      }
      return true;
    }
    addressController.clear();
    _cartService.setAddress(null);
    rebuildUi();
    await _dialogService.showDialog(
      title: 'Dirección no disponible',
      description:
          'La dirección elegida ya no existe. Elegí otra para continuar.',
      buttonTitle: 'Aceptar',
    );
    return false;
  }

  final TextEditingController deliveryDetailsController =
      TextEditingController();

  Future<void> confirmOrder() async {
    if (order == null) return;

    if (!_customerService.isUserLoggedIn) {
      await _dialogService.showDialog(
        title: 'Iniciá sesión para continuar',
        description: 'Necesitás una cuenta para confirmar el pedido.',
        buttonTitle: 'Aceptar',
      );
      await _navigationService.navigateToLoginView();
      return;
    }

    // Sin la cotización que se le mostró al cliente no se confirma.
    final quoted = _quote;
    if (quoted == null) return;
    final version = _quoteVersion;

    setBusy(true);

    // Lo que se confirma es lo que se cotizó: se toma ahora, antes de esperar.
    final paymentMethod = _selectedPaymentMethod;
    final mode = _mode;
    final receiver = _receiver;
    final selectedDate = _selectedDate;
    final timeSlotId =
        mode == DeliveryMode.express ? null : _selectedTimeSlotId;
    final slot = mode == DeliveryMode.express ? null : _selectedSlot;
    final notes = deliveryDetailsController.text;

    // La dirección tiene que seguir vigente: pudo borrarse desde otra pantalla.
    if (!await _addressStillValid()) {
      setBusy(false);
      return;
    }

    // Si mientras tanto cambió algo que mueve el precio (la dirección se
    // corrigió), la cotización mostrada ya no vale: se corta y se vuelve a pedir.
    if (_disposed) return;
    if (version != _quoteVersion || !identical(_quote, quoted)) {
      setBusy(false);
      scheduleQuote(immediate: true);
      return;
    }

    // Update order with new fields. La franja seleccionada aporta la ventana
    // horaria para mostrar; su id se manda aparte al backend (timeSlotId).
    final updatedOrder = order!.copyWith(
      requestedDeliveryDate: selectedDate,
      deliveryWindowStart: slot?.startTime,
      deliveryWindowEnd: slot?.endTime,
      paymentMethod: paymentMethod,
      customerNotes: notes,
      total: quoted.total,
    );

    // El back arma el pedido con el carrito y lo vacía en la misma transacción:
    // la app sólo vuelve a pedirlo (viene vacío) y no borra nada por su cuenta.
    final result = await _historyService.createOrder(
      updatedOrder,
      timeSlotId: timeSlotId,
      fromCart: true,
      deliveryMode: mode,
      receiver: receiver,
    );

    if (result.success) {
      await _cartService.refresh();

      // El total viaja calculado por el back en el alta (no se manda desde la
      // app): si difiere del que se mostró, se avisa con el real antes de
      // seguir al pago.
      final charged = result.order?.total;
      if (charged != null && (charged - quoted.total).abs() > 0.009) {
        await _dialogService.showDialog(
          title: 'El total cambió',
          description:
              'El total final de tu pedido es ${money.format(charged)} '
              '(te habíamos mostrado ${money.format(quoted.total)}).',
          buttonTitle: 'Aceptar',
        );
      }

      if (paymentMethod == PaymentMethod.mercadoPago) {
        await _openMercadoPagoCheckout(result.paymentUrl);
      }

      // Con el pedido hecho es cuando tiene sentido el aviso de estados.
      unawaited(_notificationService.requestPermissionAndRegister());

      final trackedOrderId = result.order?.id ?? updatedOrder.id;
      // Se vuelve al inicio y se abre el seguimiento encima: «Volver» no cae
      // en el carrito ni en el checkout.
      await _navigationService.clearTillFirstAndShow(
        Routes.orderTrackingView,
        arguments: OrderTrackingViewArguments(orderId: trackedOrderId),
      );
    } else if (result.expressUnavailableReason != null) {
      // No se creó nada: el express dejó de estar disponible entre que se
      // eligió y se confirmó. Se vuelve al reparto común, que pide franja.
      await _dialogService.showDialog(
        title: 'El express ya no está disponible',
        description: '${result.message ?? ''}\n\nPodés pedir con el reparto '
            'común y elegir una franja de entrega.',
        buttonTitle: 'Aceptar',
      );
      _deliveryNotice = result.message;
      _backToStandard();
      unawaited(loadDeliveryOptions(force: true));
    } else if (result.idempotencyConflict) {
      // El primer envío llegó con otros datos: no se manda otro pedido.
      await _dialogService.showDialog(
        title: 'Revisá Mis pedidos',
        description: result.message ?? kOrderMaybeCreatedText,
        buttonTitle: 'Aceptar',
      );
      await _navigationService.navigateToOrdersView();
    } else {
      await _dialogService.showDialog(
        title: 'No pudimos crear tu pedido',
        description: result.message ??
            'No se pudo crear la orden. Verificá tu conexión e intentá nuevamente.',
      );
      // Si el rechazo fue por el carrito (vacío o con ítems dados de baja) se
      // lo muestra tal como está en el back para que el cliente lo arregle.
      await _cartService.refresh();
      final cart = _cartService.cart;
      if (cart.isEmpty || cart.hasUnavailableItems) {
        await _navigationService.navigateToCartView();
      }
    }

    setBusy(false);
  }

  /// Abre el checkout de MercadoPago (Checkout Pro) en un WebView embebido:
  /// el pago no sale de la app. El pedido ya fue creado en este punto; el
  /// backend lo despachará cuando MercadoPago confirme el pago vía webhook
  /// (esta pantalla no inventa una confirmación local, solo interpreta a qué
  /// back_url redirigió MP). Si no llegó `paymentUrl`, avisamos con un dialog
  /// pero igual dejamos avanzar al tracking, ya que el pedido quedó creado.
  Future<void> _openMercadoPagoCheckout(String? paymentUrl) async {
    if (paymentUrl == null || paymentUrl.isEmpty) {
      await _dialogService.showDialog(
        title: 'No se pudo iniciar el pago',
        description:
            'El pedido se creó, pero no pudimos obtener el link de pago de Mercado Pago. '
            'Podés reintentar el pago desde el seguimiento del pedido.',
        buttonTitle: 'Aceptar',
      );
      return;
    }

    final outcome = await _navigationService.navigateToPaymentWebViewView(
      paymentUrl: paymentUrl,
    );

    await _showPaymentOutcomeDialog(
      outcome is PaymentOutcome ? outcome : null,
    );
  }

  Future<void> _showPaymentOutcomeDialog(PaymentOutcome? outcome) async {
    switch (outcome) {
      case PaymentOutcome.success:
        await _dialogService.showDialog(
          title: 'Pago realizado',
          description:
              'Recibimos tu pago. Tu pedido se confirma automáticamente ni bien '
              'Mercado Pago nos avisa; podés seguir el estado desde el seguimiento.',
          buttonTitle: 'Aceptar',
        );
        break;
      case PaymentOutcome.pending:
        await _dialogService.showDialog(
          title: 'Pago pendiente',
          description:
              'Tu pago quedó pendiente de confirmación de Mercado Pago. '
              'Te avisamos cuando se acredite.',
          buttonTitle: 'Aceptar',
        );
        break;
      case PaymentOutcome.failure:
      case PaymentOutcome.cancelled:
      case null:
        await _dialogService.showDialog(
          title: 'El pago no se completó',
          description: 'El pedido se creó, pero el pago no se confirmó. '
              'Podés reintentar el pago desde el seguimiento del pedido.',
          buttonTitle: 'Aceptar',
        );
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _quoteTimer?.cancel();
    deliveryDetailsController.dispose();
    super.dispose();
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [_cartService];
}
