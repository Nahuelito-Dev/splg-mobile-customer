import 'package:stacked/stacked.dart';

import 'package:splg_lib/domain/order.dart';

class CartService with ListenableServiceMixin {
  CartService() {
    listenToReactiveValues([_order]);
  }

  final ReactiveValue<Order?> _order = ReactiveValue(null);
  Order? get order => _order.value;

  void setOrder(Order order) {
    _order.value = order;
    notifyListeners();
  }

  void clearOrder() {
    _order.value = null;
    notifyListeners();
  }
}
