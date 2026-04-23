import 'package:stacked/stacked.dart';

import 'package:jennygas_lib/domain/order.dart';

class CartService with ListenableServiceMixin {
  CartService() {
    listenToReactiveValues([_order, _editingOrderId]);
  }

  final ReactiveValue<Order?> _order = ReactiveValue(null);
  Order? get order => _order.value;
  final ReactiveValue<String?> _editingOrderId = ReactiveValue(null);
  String? get editingOrderId => _editingOrderId.value;

  void setOrder(Order order) {
    _order.value = order;
    notifyListeners();
  }

  void startEditingOrder(String orderId) {
    _editingOrderId.value = orderId;
    notifyListeners();
  }

  void clearEditingOrder() {
    _editingOrderId.value = null;
    notifyListeners();
  }

  void clearOrder() {
    _order.value = null;
    _editingOrderId.value = null;
    notifyListeners();
  }
}
