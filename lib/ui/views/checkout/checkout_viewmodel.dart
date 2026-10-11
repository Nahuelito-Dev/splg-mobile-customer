import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/pricing.dart';
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
    // El carrito se arma antes del login (sin dirección): al llegar acá se
    // toma la predeterminada (o la primera) de las direcciones guardadas.
    var address = _cartService.order?.address;
    final saved = _customerService.customer.addresses;
    if (address != null && saved.isNotEmpty) {
      // Si se borró o editó en otra pantalla, vale la vigente (o ninguna).
      address = _current(address);
      final current = address;
      if (current != null && current != _cartService.order?.address) {
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
    _selectedPaymentMethod =
        _cartService.order?.paymentMethod ?? PaymentMethod.cash;
    setBusy(false);
    // Trae las franjas de la fecha por defecto (hoy) para que el cliente elija.
    loadTimeSlots();
  }

  void setPaymentMethod(PaymentMethod method) {
    _selectedPaymentMethod = method;
    paymentOpen = false;
    rebuildUi();
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
    if (_customerService.customer.addresses.isEmpty) {
      await _addAddress();
      return;
    }
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Selecciona una dirección',
      data: {'selectedId': _cartService.order?.address?.addressId},
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
    final newOrder = _cartService.order?.copyWith(address: address);
    if (newOrder != null) {
      _cartService.setOrder(newOrder);
    }
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
    if (!stillValid) _selectedTimeSlotId = null;

    _loadingTimeSlots = false;
    notifyListeners();
  }

  void selectTimeSlot(String timeSlotId) {
    _selectedTimeSlotId = timeSlotId;
    notifyListeners();
  }

  TimeSlotAvailability? get _selectedSlot {
    for (final slot in _timeSlots) {
      if (slot.timeSlotId == _selectedTimeSlotId) return slot;
    }
    return null;
  }

  double getSubtotal(OrderItem item) => Pricing.subtotal(item);

  Discount? getAppliedDiscount(OrderItem item) =>
      Pricing.applied(item.cylinder, item.quantity);

  double get itemsTotal {
    if (order == null) return 0;
    return order!.items.fold(0, (sum, item) => sum + getSubtotal(item));
  }

  double get transferSurcharge {
    if (_selectedPaymentMethod == PaymentMethod.online) {
      return itemsTotal * 0.10;
    }
    return 0;
  }

  double get finalTotal => itemsTotal + transferSurcharge;

  bool get canConfirmOrder {
    return order != null &&
        order!.items.isNotEmpty &&
        addressController.text.isNotEmpty &&
        _selectedTimeSlotId != null;
  }

  /// Reloj del checkout; los tests lo fijan para que el golden no dependa del día.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  DateTime _selectedDate = now();
  DateTime get selectedDate => _selectedDate;

  String get formattedDate =>
      DateFormat('dd/MM/yyyy', 'es_AR').format(_selectedDate);

  Future<void> selectDate(BuildContext context) async {
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
    }
  }

  /// Antes de mandar el pedido: relee las direcciones (si no puede, usa las
  /// locales) y comprueba que la elegida siga existiendo. Si no, la saca del
  /// carrito y avisa.
  Future<bool> _addressStillValid() async {
    try {
      await _customerService.refreshAddresses();
    } catch (_) {}
    final chosen = _cartService.order?.address;
    final current = _current(chosen);
    if (current != null) {
      if (current != chosen) _setOrderAddress(current);
      return true;
    }
    addressController.clear();
    final order = _cartService.order;
    if (order != null) _cartService.setOrder(order.copyWith(address: null));
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

    setBusy(true);

    // La dirección tiene que seguir vigente: pudo borrarse desde otra pantalla.
    if (!await _addressStillValid()) {
      setBusy(false);
      return;
    }

    // Update order with new fields. La franja seleccionada aporta la ventana
    // horaria para mostrar; su id se manda aparte al backend (timeSlotId).
    final slot = _selectedSlot;
    final updatedOrder = order!.copyWith(
      requestedDeliveryDate: _selectedDate,
      deliveryWindowStart: slot?.startTime,
      deliveryWindowEnd: slot?.endTime,
      paymentMethod: _selectedPaymentMethod,
      customerNotes: deliveryDetailsController.text,
      total: finalTotal,
    );

    _cartService.setOrder(updatedOrder);
    final editingOrderId = _cartService.editingOrderId;
    final isEditingCurrentOrder =
        editingOrderId != null && updatedOrder.id == editingOrderId;

    if (isEditingCurrentOrder) {
      final success = await _historyService.updateOrder(
        editingOrderId,
        updatedOrder,
        timeSlotId: _selectedTimeSlotId,
      );

      if (success) {
        _cartService.clearEditingOrder();
        _cartService.clearOrder();
        _navigationService.back();
      } else {
        await _dialogService.showDialog(
          title: 'Error al modificar pedido',
          description:
              'No se pudo modificar la orden. Verificá tu conexión e intentá nuevamente.',
        );
      }

      setBusy(false);
      return;
    }

    final result = await _historyService.createOrder(
      updatedOrder,
      timeSlotId: _selectedTimeSlotId,
    );

    if (result.success) {
      _cartService.clearEditingOrder();
      _cartService.clearOrder();

      if (_selectedPaymentMethod == PaymentMethod.mercadoPago) {
        await _openMercadoPagoCheckout(result.paymentUrl);
      }

      // Con el pedido hecho es cuando tiene sentido el aviso de estados.
      unawaited(_notificationService.requestPermissionAndRegister());

      final trackedOrderId = result.order?.id ?? updatedOrder.id;
      await _navigationService.replaceWithOrderTrackingView(
        orderId: trackedOrderId,
      );
    } else {
      await _dialogService.showDialog(
        title: 'Error al crear pedido',
        description:
            'No se pudo crear la orden. Verificá tu conexión e intentá nuevamente.',
      );
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
    deliveryDetailsController.dispose();
    super.dispose();
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [_cartService];
}
