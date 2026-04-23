import 'dart:async';

import 'package:jennygas_lib/domain/order.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/app/app.router.dart';
import 'package:jennigas_customer/services/history_service.dart';
import 'package:jennigas_customer/services/cart_service.dart';

class HistoryModel extends ReactiveViewModel {
  final _historyService = locator<HistoryService>();
  final _navigationService = locator<NavigationService>();
  final _cartService = locator<CartService>();
  final _dialogService = locator<DialogService>();
  Timer? _historyPollingTimer;
  bool _isOpeningTracking = false;
  String? _lastOpenedTrackingOrderId;

  List<Order> get history => _historyService.history;

  Future<void> initialize() async {
    setBusy(true);
    await _historyService.initialize();
    _startHistoryPolling();
    setBusy(false);
    maybeOpenTracking();
  }

  void repeatOrder(Order order) {
    _cartService.setOrder(order);
    _cartService.clearEditingOrder();
    _navigationService.navigateToCheckoutView();
  }

  void modifyOrder(Order order) {
    _cartService.setOrder(order);
    _cartService.startEditingOrder(order.id);
    _navigationService.navigateToCheckoutView();
  }

  void openTracking(Order order) {
    _lastOpenedTrackingOrderId = order.id;
    _navigationService.navigateToOrderTrackingView(orderId: order.id);
  }

  void maybeOpenTracking() {
    final trackableOrder = _findTrackableOrder();
    if (trackableOrder == null) {
      _lastOpenedTrackingOrderId = null;
      return;
    }

    if (_isOpeningTracking || _lastOpenedTrackingOrderId == trackableOrder.id) {
      return;
    }

    _isOpeningTracking = true;
    _lastOpenedTrackingOrderId = trackableOrder.id;
    _navigationService
        .navigateToOrderTrackingView(
          orderId: trackableOrder.id,
          preventDuplicates: false,
        )
        .whenComplete(() => _isOpeningTracking = false);
  }

  Future<void> cancelOrder(Order order) async {
    setBusy(true);
    final success = await _historyService.cancelOrder(order.id);
    if (!success) {
      await _dialogService.showDialog(
        title: 'Error al cancelar pedido',
        description:
            'No se pudo cancelar la orden en este momento. Intentá nuevamente.',
      );
    }
    setBusy(false);
  }

  @override
  List<ListenableServiceMixin> get listenableServices => [_historyService];

  void _startHistoryPolling() {
    _historyPollingTimer?.cancel();
    _historyPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _historyService.refreshHistory();
      maybeOpenTracking();
    });
  }

  Order? _findTrackableOrder() {
    for (final order in _historyService.history) {
      if (order.status == OrderStatus.accepted ||
          order.status == OrderStatus.outForDelivery) {
        return order;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _historyPollingTimer?.cancel();
    super.dispose();
  }
}
