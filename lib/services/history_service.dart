import 'package:stacked/stacked.dart';

import 'package:jennygas_lib/domain/order.dart';
import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/data/datasource/order_remote_datasource.dart';
import 'package:jennigas_customer/data/repository/order_repository_imp.dart';
import 'package:jennigas_customer/domain/repository/order_repository.dart';
import 'package:jennigas_customer/domain/usecases/create_order_usecases.dart';
import 'package:jennigas_customer/domain/usecases/fetch_customer_orders_usecases.dart';
import 'package:jennigas_customer/domain/usecases/update_order_status_usecases.dart';
import 'package:jennigas_customer/services/customer_service.dart';

class HistoryService with ListenableServiceMixin {
  HistoryService() {
    _orderRepository = OrderRepositoryImp(_orderDatasource);
    _createOrderUseCase = CreateOrderUseCase(_orderRepository);
    _fetchCustomerOrdersUseCase = FetchCustomerOrdersUseCase(_orderRepository);
    _updateOrderStatusUseCase = UpdateOrderStatusUseCase(_orderRepository);
    listenToReactiveValues([_history]);
  }

  final _customerService = locator<CustomerService>();
  final _orderDatasource = OrderRemoteDatasource();
  late OrderRepository _orderRepository;
  late CreateOrderUseCase _createOrderUseCase;
  late FetchCustomerOrdersUseCase _fetchCustomerOrdersUseCase;
  late UpdateOrderStatusUseCase _updateOrderStatusUseCase;

  final ReactiveValue<bool> _hasPendingOrder = ReactiveValue<bool>(false);
  bool get hasPendingOrder => _hasPendingOrder.value;

  final ReactiveList<Order> _history = ReactiveList<Order>();
  List<Order> get history => _history;

  Future<void> initialize() async {
    await getHistory();
    notifyListeners();
  }

  void addOrder(Order order) {
    createOrder(order);
  }

  Future<bool> createOrder(Order order) async {
    final token = await _customerService.token;
    if (token == null) {
      return false;
    }

    final createdOrder =
        await _createOrderUseCase(_toCreateOrderPayload(order), token);
    if (createdOrder == null) {
      return false;
    }

    _history.removeWhere((historyOrder) => historyOrder.id == createdOrder.id);
    _history.insert(0, createdOrder);
    _hasPendingOrder.value = _history
        .any((historyOrder) => historyOrder.status == OrderStatus.pending);
    notifyListeners();
    return true;
  }

  Future<bool> updateOrder(String orderId, Order order) async {
    final token = await _customerService.token;
    if (token == null) {
      return false;
    }

    final updatedOrder = await _orderRepository.updateOrder(
      orderId,
      _toUpdateOrderPayload(order),
      token,
    );
    if (updatedOrder == null) {
      return false;
    }

    _history.removeWhere((historyOrder) => historyOrder.id == updatedOrder.id);
    _history.insert(0, updatedOrder);
    _hasPendingOrder.value = _history
        .any((historyOrder) => historyOrder.status == OrderStatus.pending);
    notifyListeners();
    return true;
  }

  Future<bool> cancelOrder(String orderId) async {
    final token = await _customerService.token;
    if (token == null) {
      return false;
    }

    final success =
        await _updateOrderStatusUseCase(orderId, 'cancelled', token);
    if (!success) {
      return false;
    }

    await refreshHistory();
    notifyListeners();
    return true;
  }

  Future<List<Order>> getHistory() async {
    if (_history.isNotEmpty) {
      return _history;
    }
    return refreshHistory();
  }

  Future<List<Order>> refreshHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await _customerService.token;
    if (token == null) {
      _history.clear();
      _hasPendingOrder.value = false;
      notifyListeners();
      return _history;
    }

    final customerId = _customerService.customer.customerId;
    final remoteHistory = await _fetchCustomerOrdersUseCase(
      customerId,
      token,
      limit: limit,
      offset: offset,
    );

    _history.clear();
    _history.addAll(remoteHistory);
    _hasPendingOrder.value = _history.any(
      (order) => order.status == OrderStatus.pending,
    );
    return _history;
  }

  Map<String, dynamic> _toCreateOrderPayload(Order order) {
    final items = order.items
        .where((item) => item.quantity > 0)
        .map((item) => {
              'gasCylinderId': item.cylinder.id,
              'quantity': item.quantity,
              'unitPrice': item.cylinder.price,
            })
        .toList();

    return {
      'customerId': _customerService.customer.customerId,
      'addressId': order.address?.addressId,
      'paymentMethod': order.paymentMethod.name,
      'items': items,
    };
  }

  Map<String, dynamic> _toUpdateOrderPayload(Order order) {
    final items = order.items
        .where((item) => item.quantity > 0)
        .map((item) => {
              'gasCylinderId': item.cylinder.id,
              'quantity': item.quantity,
              'unitPrice': item.cylinder.price,
            })
        .toList();

    return {
      'addressId': order.address?.addressId,
      'paymentMethod': order.paymentMethod.name,
      'items': items,
    };
  }
}
