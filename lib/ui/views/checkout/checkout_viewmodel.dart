import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jennygas_lib/domain/order.dart';
import 'package:jennygas_lib/domain/address.dart';
import 'package:jennygas_lib/domain/discount.dart';
import 'package:jennygas_lib/domain/order_item.dart';
import 'package:jennigas_customer/app/app.router.dart';
import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/services/cart_service.dart';
import 'package:jennigas_customer/domain/business_hours.dart';
import 'package:jennigas_customer/services/history_service.dart';
import 'package:jennigas_customer/services/customer_service.dart';
import 'package:jennigas_customer/app/app.bottomsheets.dart';

class CheckoutViewModel extends ReactiveViewModel {
  final _cartService = locator<CartService>();
  final _historyService = locator<HistoryService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _dialogService = locator<DialogService>();

  Order? get order => _cartService.order;

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  PaymentMethod get selectedPaymentMethod => _selectedPaymentMethod;

  final TextEditingController addressController = TextEditingController();

  late BusinessHours _businessHours;

  void initialize() {
    setBusy(true);
    _businessHours = BusinessHours(
      morningStart: 9,
      morningEnd: 13,
      afternoonStart: 17,
      afternoonEnd: 21,
    );

    addressController.text = _cartService.order?.address?.streetName ?? '';
    _selectedPaymentMethod =
        _cartService.order?.paymentMethod ?? PaymentMethod.cash;
    setBusy(false);
  }

  void setPaymentMethod(PaymentMethod method) {
    _selectedPaymentMethod = method;
    rebuildUi();
  }

  Future<void> openMap() async {
    final result = await _navigationService.navigateToMapView();
    if (result != null && result is Address) {
      addressController.text = result.streetName;
      _setOrderAddress(result);
      _customerService.addAddress(result);
    }
  }

  Future<void> showAddressList() async {
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Selecciona una dirección',
    );

    if (response?.confirmed == true && response?.data is Address) {
      final address = response!.data as Address;
      addressController.text = address.streetName;
      _setOrderAddress(address);
      rebuildUi();
    }
  }

  void _setOrderAddress(Address address) {
    final newOrder = _cartService.order?.copyWith(address: address);
    if (newOrder != null) {
      _cartService.setOrder(newOrder);
    }
  }

  int? get selectedStartHour => _businessHours.selectedStartHour;

  int? get selectedEndHour => _businessHours.selectedEndHour;

  List<int> get availableStartHours => _businessHours.availableStartHours;

  List<int> get availableEndHours => _businessHours.availableEndHours;

  void setStartHour(int? hour) {
    _businessHours.setStartHour(hour);
    notifyListeners();
  }

  void setEndHour(int? hour) {
    _businessHours.setEndHour(hour);
    notifyListeners();
  }

  // Discount and Total Calculation Logic
  double getSubtotal(OrderItem item) {
    double subtotal = item.cylinder.price * item.quantity;

    // Find best discount for the quantity of this specific cylinder
    if (item.cylinder.discounts != null &&
        item.cylinder.discounts!.isNotEmpty) {
      Discount? bestDiscount;
      // Assumes discounts are sorted by quantity ascending or logic handles it.
      // We check all discounts and find the one that fits.
      for (final discount in item.cylinder.discounts!) {
        if (item.quantity >= discount.quantity) {
          // Keep the one with highest quantity threshold that we met
          if (bestDiscount == null ||
              discount.quantity > bestDiscount.quantity) {
            bestDiscount = discount;
          }
        }
      }

      if (bestDiscount != null) {
        subtotal = subtotal * (1 - bestDiscount.percentage / 100);
      }
    }
    return subtotal;
  }

  Discount? getAppliedDiscount(OrderItem item) {
    if (item.cylinder.discounts == null || item.cylinder.discounts!.isEmpty) {
      return null;
    }

    Discount? bestDiscount;
    for (final discount in item.cylinder.discounts!) {
      if (item.quantity >= discount.quantity) {
        if (bestDiscount == null || discount.quantity > bestDiscount.quantity) {
          bestDiscount = discount;
        }
      }
    }
    return bestDiscount;
  }

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
        _businessHours.selectedStartHour != null &&
        _businessHours.selectedEndHour != null;
  }

  DateTime _selectedDate = DateTime.now();
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
    }
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

    // Update order with new fields
    final updatedOrder = order!.copyWith(
      requestedDeliveryDate: _selectedDate,
      deliveryWindowStart: _formatHour(_businessHours.selectedStartHour),
      deliveryWindowEnd: _formatHour(_businessHours.selectedEndHour),
      paymentMethod: _selectedPaymentMethod,
      customerNotes: deliveryDetailsController.text,
      total: finalTotal,
    );

    _cartService.setOrder(updatedOrder);
    final editingOrderId = _cartService.editingOrderId;
    final isEditingCurrentOrder =
        editingOrderId != null && updatedOrder.id == editingOrderId;

    if (isEditingCurrentOrder) {
      final success =
          await _historyService.updateOrder(editingOrderId, updatedOrder);

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

    final result = await _historyService.createOrder(updatedOrder);

    if (result.success) {
      _cartService.clearEditingOrder();
      _cartService.clearOrder();

      if (_selectedPaymentMethod == PaymentMethod.mercadoPago) {
        await _openMercadoPagoCheckout(result.paymentUrl);
      }

      final trackedOrderId = _historyService.history.isNotEmpty
          ? _historyService.history.first.id
          : updatedOrder.id;
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

  /// Abre el checkout de MercadoPago (Checkout Pro) en el navegador externo.
  /// El pedido ya fue creado en este punto; el backend lo despachará cuando
  /// MercadoPago confirme el pago vía webhook. Si no llegó `paymentUrl` o
  /// falla el launch, avisamos con un dialog pero igual dejamos avanzar al
  /// tracking, ya que el pedido quedó creado.
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

    final uri = Uri.tryParse(paymentUrl);
    var launched = false;

    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      await _dialogService.showDialog(
        title: 'No se pudo abrir Mercado Pago',
        description:
            'El pedido se creó, pero no pudimos abrir el link de pago. '
            'Podés reintentar el pago desde el seguimiento del pedido.',
        buttonTitle: 'Aceptar',
      );
    }
  }

  String? _formatHour(int? hour) {
    if (hour == null) return null;
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  @override
  void dispose() {
    deliveryDetailsController.dispose();
    super.dispose();
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [_cartService];
}
