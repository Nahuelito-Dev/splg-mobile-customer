import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/data/repository/order_repository_imp.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/usecases/create_order_usecases.dart';
import 'package:splg_customer/domain/usecases/fetch_customer_orders_usecases.dart';
import 'package:splg_customer/domain/usecases/cancel_order_usecases.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/domain/cancel_result.dart';

class HistoryService with ListenableServiceMixin {
  /// [orderRepository] sólo se inyecta en los tests.
  HistoryService({OrderRepository? orderRepository}) {
    _orderRepository = orderRepository ?? OrderRepositoryImp(_orderDatasource);
    _createOrderUseCase = CreateOrderUseCase(_orderRepository);
    _fetchCustomerOrdersUseCase = FetchCustomerOrdersUseCase(_orderRepository);
    _cancelOrderUseCase = CancelOrderUseCase(_orderRepository);
    listenToReactiveValues([_history]);
  }

  final _customerService = locator<CustomerService>();
  final _notificationService = locator<NotificationService>();
  final _orderDatasource = OrderRemoteDatasource();
  late OrderRepository _orderRepository;
  late CreateOrderUseCase _createOrderUseCase;
  late FetchCustomerOrdersUseCase _fetchCustomerOrdersUseCase;
  late CancelOrderUseCase _cancelOrderUseCase;

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

  Future<CreateOrderResult> createOrder(
    Order order, {
    String? timeSlotId,
  }) async {
    final token = await _customerService.token;
    if (token == null) {
      return const CreateOrderResult(success: false);
    }

    final notificationToken = await _notificationService.currentToken;
    final result = await _createOrderUseCase(
      _toCreateOrderPayload(order, timeSlotId, notificationToken),
      token,
    );
    final createdOrder = result.order;
    if (!result.success || createdOrder == null) {
      return CreateOrderResult(success: false, paymentUrl: result.paymentUrl);
    }

    _history.removeWhere((historyOrder) => historyOrder.id == createdOrder.id);
    _history.insert(0, createdOrder);
    _hasPendingOrder.value = _history
        .any((historyOrder) => historyOrder.status == OrderStatus.pending);
    notifyListeners();
    return CreateOrderResult(
      success: true,
      order: createdOrder,
      paymentUrl: result.paymentUrl,
    );
  }

  Future<bool> updateOrder(
    String orderId,
    Order order, {
    String? timeSlotId,
  }) async {
    final token = await _customerService.token;
    if (token == null) {
      return false;
    }

    final updatedOrder = await _orderRepository.updateOrder(
      orderId,
      _toUpdateOrderPayload(order, timeSlotId),
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

  Future<CancelResult> cancelOrder(String orderId) async {
    final token = await _customerService.token;
    if (token == null) {
      return const CancelResult.failed();
    }

    final result = await _cancelOrderUseCase(orderId, token);
    if (!result.success) {
      // Un rechazo de negocio ("ya finalizado", "ya está en camino") indica que
      // el pedido cambió de estado: se refresca para que la pantalla lo refleje.
      if (result.isRejected) {
        await refreshHistory();
        notifyListeners();
      }
      return result;
    }

    await refreshHistory();
    notifyListeners();
    return result;
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

  Map<String, dynamic> _toCreateOrderPayload(
    Order order,
    String? timeSlotId, [
    String? notificationToken,
  ]) {
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
      'paymentMethod': OrderApiMapper.serializePaymentMethod(
        order.paymentMethod,
      ),
      'items': items,
      // Agendamiento: fecha (YYYY-MM-DD) + franja, más las notas del cliente.
      // Antes se recogían en el checkout pero NO se enviaban (se perdían).
      ..._schedulingPayload(order, timeSlotId),
      // Token FCM del device: el backend lo usa para notificar el estado de
      // ESTE pedido aunque `notification_token` del customer todavía no esté
      // seteado (p.ej. primer pedido justo después de otorgar el permiso).
      if (notificationToken != null && notificationToken.isNotEmpty)
        'notificationToken': notificationToken,
    };
  }

  Map<String, dynamic> _toUpdateOrderPayload(Order order, String? timeSlotId) {
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
      'paymentMethod': OrderApiMapper.serializePaymentMethod(
        order.paymentMethod,
      ),
      'items': items,
      ..._schedulingPayload(order, timeSlotId),
    };
  }

  /// Campos de agendamiento comunes a create/update, con los nombres que espera
  /// el backend (`scheduledDate`, `timeSlotId`, `notes`). Solo incluye cada
  /// clave si hay dato, para no pisar con null.
  Map<String, dynamic> _schedulingPayload(Order order, String? timeSlotId) {
    final payload = <String, dynamic>{};

    final date = order.requestedDeliveryDate;
    if (date != null) {
      payload['scheduledDate'] = DateFormat('yyyy-MM-dd').format(date);
    }
    if (timeSlotId != null && timeSlotId.isNotEmpty) {
      payload['timeSlotId'] = timeSlotId;
    }
    final notes = order.customerNotes;
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }

    return payload;
  }
}
