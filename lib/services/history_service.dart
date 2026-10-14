import 'dart:developer';

import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/order_gone.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/data/datasource/order_remote_datasource.dart';
import 'package:splg_customer/data/mappers/order_api_mapper.dart';
import 'package:splg_customer/data/repository/order_repository_imp.dart';
import 'package:splg_customer/domain/create_order_result.dart';
import 'package:splg_customer/domain/order_quote.dart';
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

  /// Época de la sesión (`reset()` la incrementa) y versión de los cambios
  /// locales (alta o edición de un pedido). Una consulta que volvió después de
  /// un cierre de sesión, o que salió antes de crear un pedido, no pisa la lista.
  int _session = 0;
  int _localChanges = 0;

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
    final session = _session;
    final token = await _customerService.token;
    if (token == null) {
      return const CreateOrderResult(
        success: false,
        message: ApiErrorText.sessionExpired,
        retryable: false,
      );
    }

    final notificationToken = await _notificationService.currentToken;
    final result = await _createOrderUseCase(
      _toCreateOrderPayload(order, timeSlotId, notificationToken),
      token,
    );
    final createdOrder = result.order;
    if (!result.success || createdOrder == null) {
      return CreateOrderResult(
        success: false,
        paymentUrl: result.paymentUrl,
        message: result.message,
        retryable: result.retryable,
        idempotencyConflict: result.idempotencyConflict,
      );
    }

    if (session == _session) {
      _localChanges++;
      _history
          .removeWhere((historyOrder) => historyOrder.id == createdOrder.id);
      _history.insert(0, createdOrder);
    }
    _hasPendingOrder.value = _history
        .any((historyOrder) => historyOrder.status == OrderStatus.pending);
    notifyListeners();
    return CreateOrderResult(
      success: true,
      order: createdOrder,
      paymentUrl: result.paymentUrl,
    );
  }

  /// Cotiza el pedido en el back (`POST /orders/quote`): promociones por
  /// volumen, recargo de zona y por medio de pago los calcula el servidor.
  Future<QuoteOutcome> quoteOrder(Order order, {String? timeSlotId}) async {
    final token = await _customerService.token;
    if (token == null) {
      return const QuoteOutcome.failed(ApiErrorText.sessionExpired,
          retryable: false);
    }
    final result = await _orderDatasource.quoteOrder(
      _toQuotePayload(order, timeSlotId),
      token,
    );
    if (!result.ok) {
      return QuoteOutcome.failed(
        result.message ?? ApiErrorText.generic,
        retryable: ApiErrorText.isRetryable(result.status),
      );
    }
    final quote = OrderQuote.fromJson(result.data);
    if (quote == null) return const QuoteOutcome.failed(ApiErrorText.generic);
    return QuoteOutcome.ok(quote);
  }

  Future<bool> updateOrder(
    String orderId,
    Order order, {
    String? timeSlotId,
  }) async {
    final session = _session;
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

    if (session == _session) {
      _localChanges++;
      _history
          .removeWhere((historyOrder) => historyOrder.id == updatedOrder.id);
      _history.insert(0, updatedOrder);
    }
    _hasPendingOrder.value = _history
        .any((historyOrder) => historyOrder.status == OrderStatus.pending);
    notifyListeners();
    return true;
  }

  Future<CancelResult> cancelOrder(String orderId, {String? reason}) async {
    final token = await _customerService.token;
    if (token == null) {
      return const CancelResult.failed();
    }

    final result = await _cancelOrderUseCase(orderId, token, reason: reason);
    if (!result.success) {
      // Un rechazo de negocio ("ya finalizado", "ya está en camino") indica que
      // el pedido cambió de estado: se refresca para que la pantalla lo refleje.
      if (result.isRejected) {
        await tryRefreshHistory();
        notifyListeners();
      }
      return result;
    }

    await tryRefreshHistory();
    notifyListeners();
    return result;
  }

  Future<List<Order>> getHistory() async {
    if (_history.isNotEmpty) {
      return _history;
    }
    return refreshHistory();
  }

  /// Trae la primera página y reemplaza el historial local. Si falla lanza y
  /// **no** toca lo que ya había: un error de red no es "sin pedidos".
  Future<List<Order>> refreshHistory({int limit = 20, int offset = 0}) async {
    final session = _session;
    final changes = _localChanges;
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
    // Cerró sesión o se creó/editó un pedido mientras la consulta volaba: la
    // respuesta es vieja, la próxima la reemplaza.
    if (session != _session || changes != _localChanges) return _history;

    _history.clear();
    _history.addAll(remoteHistory);
    _hasPendingOrder.value = _history.any(
      (order) => order.status == OrderStatus.pending,
    );
    return _history;
  }

  /// Como [refreshHistory] pero sin lanzar: devuelve si se pudo. Para quien
  /// sólo quiere "lo más fresco posible" (banner del inicio, tras cancelar).
  Future<bool> tryRefreshHistory({int limit = 20}) async {
    try {
      await refreshHistory(limit: limit);
      return true;
    } catch (e) {
      log('refreshHistory falló: $e');
      return false;
    }
  }

  /// Una página del historial para "Mis pedidos". No toca la lista del inicio
  /// ([history]); lanza ante cualquier error.
  Future<OrdersPage> fetchOrdersPage({int limit = 20, int offset = 0}) async {
    final session = _session;
    final token = await _customerService.token;
    if (token == null) throw const LoadFailure(ApiErrorText.sessionExpired);
    final page = await _orderRepository.fetchCustomerPage(
      _customerService.customer.customerId,
      token,
      limit: limit,
      offset: offset,
    );
    if (session != _session) {
      throw const LoadFailure(ApiErrorText.sessionExpired);
    }
    return page;
  }

  /// Un pedido por id; lanza ante cualquier error.
  Future<Order> fetchOrder(String orderId) async {
    final token = await _customerService.token;
    if (token == null) throw const LoadFailure(ApiErrorText.sessionExpired);
    try {
      return await _orderRepository.fetchOrder(orderId, token);
    } catch (e) {
      if (isOrderGone(e)) throw orderGoneFailure;
      rethrow;
    }
  }

  /// Limpia lo del usuario anterior (cierre de sesión / baja de cuenta).
  void reset() {
    _session++;
    _history.clear();
    _hasPendingOrder.value = false;
    _cancelOrderUseCase.clear();
    _createOrderUseCase.clear();
    notifyListeners();
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

  /// Mismo cuerpo que el alta, sin el token de notificaciones.
  Map<String, dynamic> _toQuotePayload(Order order, String? timeSlotId) =>
      _toCreateOrderPayload(order, timeSlotId);

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
