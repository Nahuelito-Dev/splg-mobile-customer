import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';

import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';

class OrderModel extends ReactiveViewModel {
  final _cartService = locator<CartService>();
  final _customerService = locator<CustomerService>();
  final _navigationService = locator<NavigationService>();
  final _gasCylinderService = locator<GasCylinderService>();
  final _historyService = locator<HistoryService>();

  List<GasCylinder> _cylinders = [];
  List<GasCylinder> get cylinders => _cylinders;

  Future<void> initialize() async {
    setBusy(true);
    await Future.wait([
      _loadCylinders(),
      _historyService.refreshHistory(limit: 20, offset: 0),
    ]);
    setBusy(false);
  }

  Future<void> _loadCylinders() async {
    _cylinders = await _gasCylinderService.getGasCylinders();
  }

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

  String get activeOrderStatusLabel {
    final order = _activeOrder;
    if (order == null) return '';
    switch (order.status) {
      case OrderStatus.pending:
        return 'Buscando chofer';
      case OrderStatus.accepted:
        return 'Chofer asignado';
      case OrderStatus.outForDelivery:
        return 'En camino';
      case OrderStatus.delivered:
        return 'Entregado';
      case OrderStatus.cancelled:
        return 'Cancelado';
    }
  }

  String get activeOrderShortCode {
    final id = activeOrderId;
    if (id.isEmpty) return '';
    return id.length > 6 ? id.substring(id.length - 6) : id;
  }

  Future<void> openActiveOrderTracking() async {
    if (!hasActiveOrder) return;
    await _navigationService.navigateToOrderTrackingView(orderId: activeOrderId);
  }

  int getItemQuantity(String cylinderId) =>
      _cartService.order?.items
          .firstWhere((item) => item.cylinder.id == cylinderId,
              orElse: () => OrderItem(
                  cylinder: _cylinders.firstWhere((c) => c.id == cylinderId),
                  quantity: 0))
          .quantity ??
      0;

  void addItem(GasCylinder cylinder, int quantity) {
    if (_cartService.order == null) {
      _createOrder();
    }

    final order = _cartService.order!;
    final item = order.items.firstWhere(
        (item) => item.cylinder.id == cylinder.id,
        orElse: () => OrderItem(cylinder: cylinder, quantity: 0));

    final newItem = item.copyWith(quantity: item.quantity + quantity);

    Order newOrder;
    if (newItem.quantity > 0) {
      final items =
          order.items.where((item) => item.cylinder.id != cylinder.id).toList();
      items.add(newItem);
      newOrder = order.copyWith(items: items);
    } else {
      final items =
          order.items.where((item) => item.cylinder.id != cylinder.id).toList();
      newOrder = order.copyWith(items: items);
    }

    _cartService.setOrder(newOrder);
  }

  void _createOrder() {
    _cartService.clearEditingOrder();
    final order = Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      address: _customerService.customer.addresses.isNotEmpty
          ? _customerService.customer.addresses.first
          : null,
      items: [],
      total: 0,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    _cartService.setOrder(order);
  }

  double get total {
    double total = 0;
    if (_cartService.order == null) return 0;
    final order = _cartService.order!;
    for (final item in order.items) {
      double subtotal = item.cylinder.price * item.quantity;
      if (item.cylinder.discounts != null &&
          item.cylinder.discounts!.isNotEmpty) {
        Discount? bestDiscount;
        for (final discount in item.cylinder.discounts!) {
          if (item.quantity >= discount.quantity) {
            bestDiscount = discount;
          } else {
            break;
          }
        }
        if (bestDiscount != null) {
          subtotal = subtotal * (1 - bestDiscount.percentage / 100);
        }
      }
      total += subtotal;
    }
    return total;
  }

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
