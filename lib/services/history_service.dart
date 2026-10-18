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
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/repository/order_repository.dart';
import 'package:splg_customer/domain/usecases/create_order_usecases.dart';
import 'package:splg_customer/domain/usecases/fetch_customer_orders_usecases.dart';
import 'package:splg_customer/domain/usecases/cancel_order_usecases.dart';
import 'package:splg_customer/domain/usecases/change_order_usecases.dart';
import 'package:splg_customer/domain/usecases/update_order_usecases.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_refund.dart';
import 'package:splg_customer/domain/update_order_result.dart';
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
    _updateOrderUseCase = UpdateOrderUseCase(_orderRepository);
    _changeOrderUseCase = ChangeOrderUseCase(_orderRepository);
    listenToReactiveValues([_history]);
  }

  final _customerService = locator<CustomerService>();
  final _notificationService = locator<NotificationService>();
  final _orderDatasource = OrderRemoteDatasource();
  late OrderRepository _orderRepository;
  late CreateOrderUseCase _createOrderUseCase;
  late FetchCustomerOrdersUseCase _fetchCustomerOrdersUseCase;
  late CancelOrderUseCase _cancelOrderUseCase;
  late UpdateOrderUseCase _updateOrderUseCase;
  late ChangeOrderUseCase _changeOrderUseCase;

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

  /// Con [fromCart] el back arma el pedido con el carrito del cliente (a precios
  /// vigentes) y lo vacía en la misma transacción: el cuerpo no lleva ítems.
  ///
  /// Con [deliveryMode] express el pedido no se agenda (ni fecha ni franja) y
  /// el back vuelve a evaluar la disponibilidad. [receiver] es quien recibe, si
  /// no es el cliente.
  Future<CreateOrderResult> createOrder(
    Order order, {
    String? timeSlotId,
    bool fromCart = false,
    DeliveryMode deliveryMode = DeliveryMode.standard,
    OrderReceiver? receiver,
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
      {
        ..._toCreateOrderPayload(
            order, timeSlotId, notificationToken, fromCart, deliveryMode),
        if (receiver != null) 'receiver': receiver.toJson(),
      },
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
        expressUnavailableReason: result.expressUnavailableReason,
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
  ///
  /// Con [orderId] es la cotización de una edición: el back cuenta el stock y
  /// el cupo que ese pedido ya ocupa y no revalida lo que no cambió.
  ///
  /// Con [fromCart] cotiza el carrito del cliente (sin ítems en el cuerpo).
  ///
  /// Con [deliveryMode] express suma el recargo express; si dejó de estar
  /// disponible responde con el motivo del back.
  Future<QuoteOutcome> quoteOrder(
    Order order, {
    String? timeSlotId,
    String? orderId,
    bool fromCart = false,
    DeliveryMode deliveryMode = DeliveryMode.standard,
  }) async {
    final token = await _customerService.token;
    if (token == null) {
      return const QuoteOutcome.failed(ApiErrorText.sessionExpired,
          retryable: false);
    }
    final result = await _orderDatasource.quoteOrder(
      {
        ..._toQuotePayload(order, timeSlotId,
            fromCart: fromCart, deliveryMode: deliveryMode),
        if (orderId != null) 'orderId': orderId,
      },
      token,
    );
    if (!result.ok) {
      final body = result.body;
      final expressReason = result.status == 409 &&
              body is Map &&
              body['code'] == 'EXPRESS_NOT_AVAILABLE'
          ? body['reason']?.toString()
          : null;
      return QuoteOutcome.failed(
        expressReason != null
            ? expressUnavailableText(expressReason)
            : result.message ?? ApiErrorText.generic,
        retryable: ApiErrorText.isRetryable(result.status),
        expressUnavailableReason: expressReason,
      );
    }
    final quote = OrderQuote.fromJson(result.data);
    if (quote == null) return const QuoteOutcome.failed(ApiErrorText.generic);
    return QuoteOutcome.ok(quote);
  }

  /// Edita un pedido pendiente (`PATCH /orders/:id`). El precio lo calcula el
  /// back: el cuerpo lleva sólo garrafas y cantidades.
  Future<UpdateOrderResult> updateOrder(
    String orderId,
    Order order, {
    String? timeSlotId,
  }) async {
    final session = _session;
    final token = await _customerService.token;
    if (token == null) {
      return const UpdateOrderResult(
          success: false, message: ApiErrorText.sessionExpired);
    }

    final result = await _updateOrderUseCase(
      orderId,
      _toUpdateOrderPayload(order, timeSlotId),
      token,
    );
    if (!result.success) return result;

    return _applyChanged(result, session);
  }

  /// Modalidades de entrega que ofrece la distribuidora para una dirección
  /// (`GET /orders/delivery-options`).
  Future<ApiResult<DeliveryOptions>> deliveryOptions(String addressId) async {
    final token = await _customerService.token;
    if (token == null) {
      return const ApiResult.fail(ApiErrorText.sessionExpired, status: 401);
    }
    return _orderRepository.deliveryOptions(addressId, token);
  }

  /// Cambia la dirección de entrega de un pedido pendiente o aceptado
  /// (`PATCH /orders/:id/address`). El total lo recalcula el back.
  Future<UpdateOrderResult> changeOrderAddress(
    String orderId,
    String addressId, {
    String? reason,
  }) async {
    final session = _session;
    final token = await _customerService.token;
    if (token == null) {
      return const UpdateOrderResult(
          success: false, message: ApiErrorText.sessionExpired);
    }
    final result = await _changeOrderUseCase
        .changeAddress(orderId, addressId, token, reason: reason);
    if (!result.success) return result;
    return _applyChanged(result, session);
  }

  /// Indica quién recibe el pedido (`PATCH /orders/:id/receiver`).
  Future<UpdateOrderResult> setOrderReceiver(
    String orderId,
    OrderReceiver receiver,
  ) async {
    final session = _session;
    final token = await _customerService.token;
    if (token == null) {
      return const UpdateOrderResult(
          success: false, message: ApiErrorText.sessionExpired);
    }
    final result =
        await _changeOrderUseCase.setReceiver(orderId, receiver, token);
    if (!result.success) return result;
    return _applyChanged(result, session);
  }

  /// Un cambio aplicado: el pedido que devolvió el back reemplaza al de la
  /// lista; si la respuesta no se pudo leer se relee el historial.
  Future<UpdateOrderResult> _applyChanged(
      UpdateOrderResult result, int session) async {
    final updatedOrder = result.order;
    if (updatedOrder == null) {
      await tryRefreshHistory();
      notifyListeners();
      return result;
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
    return result;
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

  /// Como [fetchOrder], con el desglose del total (recargos) y el estado del
  /// cobro; lanza ante cualquier error.
  Future<OrderDetail> fetchOrderDetail(String orderId) async {
    final token = await _customerService.token;
    if (token == null) throw const LoadFailure(ApiErrorText.sessionExpired);
    try {
      return await _orderRepository.fetchOrderDetail(orderId, token);
    } catch (e) {
      if (isOrderGone(e)) throw orderGoneFailure;
      rethrow;
    }
  }

  /// Las devoluciones del pago del pedido (`GET /orders/:id/refunds/mine`);
  /// lista vacía si no hubo ninguna y null si no se pudo leer (que no es lo
  /// mismo que "sin reintegro").
  Future<List<OrderRefund>?> fetchOrderRefunds(String orderId) async {
    final token = await _customerService.token;
    if (token == null) return null;
    final result = await _orderDatasource.fetchMyRefunds(orderId, token);
    if (!result.ok) return null;
    return OrderRefund.listFromJson(result.data);
  }

  /// Limpia lo del usuario anterior (cierre de sesión / baja de cuenta).
  void reset() {
    _session++;
    _history.clear();
    _hasPendingOrder.value = false;
    _cancelOrderUseCase.clear();
    _createOrderUseCase.clear();
    _updateOrderUseCase.clear();
    _changeOrderUseCase.clear();
    notifyListeners();
  }

  Map<String, dynamic> _toCreateOrderPayload(
    Order order,
    String? timeSlotId, [
    String? notificationToken,
    bool fromCart = false,
    DeliveryMode deliveryMode = DeliveryMode.standard,
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
      if (fromCart) 'fromCart': true else 'items': items,
      // Agendamiento: fecha (YYYY-MM-DD) + franja, más las notas del cliente.
      // Antes se recogían en el checkout pero NO se enviaban (se perdían).
      // El express no se agenda: sin fecha ni franja.
      ..._schedulingPayload(order, timeSlotId,
          scheduled: deliveryMode != DeliveryMode.express),
      if (deliveryMode == DeliveryMode.express)
        'deliveryMode': deliveryMode.wire,
      // Token FCM del device: el backend lo usa para notificar el estado de
      // ESTE pedido aunque `notification_token` del customer todavía no esté
      // seteado (p.ej. primer pedido justo después de otorgar el permiso).
      if (notificationToken != null && notificationToken.isNotEmpty)
        'notificationToken': notificationToken,
    };
  }

  /// Mismo cuerpo que el alta, sin el token de notificaciones.
  Map<String, dynamic> _toQuotePayload(Order order, String? timeSlotId,
          {bool fromCart = false,
          DeliveryMode deliveryMode = DeliveryMode.standard}) =>
      _toCreateOrderPayload(order, timeSlotId, null, fromCart, deliveryMode);

  /// Cuerpo de la edición: sin precios (los pone el back). Sólo lleva lo que
  /// el cliente cambió: sin `customerNotes` no manda notas (con '' las vacía) y
  /// sin `requestedDeliveryDate` no manda fecha.
  Map<String, dynamic> _toUpdateOrderPayload(Order order, String? timeSlotId) {
    final items = order.items
        .where((item) => item.quantity > 0)
        .map((item) => {
              'gasCylinderId': item.cylinder.id,
              'quantity': item.quantity,
            })
        .toList();

    return {
      'addressId': order.address?.addressId,
      'paymentMethod': OrderApiMapper.serializePaymentMethod(
        order.paymentMethod,
      ),
      'items': items,
      ..._schedulingPayload(order, timeSlotId),
      if (order.customerNotes != null) 'notes': order.customerNotes!.trim(),
    };
  }

  /// Campos de agendamiento comunes a create/update, con los nombres que espera
  /// el backend (`scheduledDate`, `timeSlotId`, `notes`). Solo incluye cada
  /// clave si hay dato, para no pisar con null.
  ///
  /// Con [scheduled] en false (pedido express) no lleva fecha ni franja.
  Map<String, dynamic> _schedulingPayload(Order order, String? timeSlotId,
      {bool scheduled = true}) {
    final payload = <String, dynamic>{};

    final date = order.requestedDeliveryDate;
    if (scheduled && date != null) {
      payload['scheduledDate'] = DateFormat('yyyy-MM-dd').format(date);
    }
    if (scheduled && timeSlotId != null && timeSlotId.isNotEmpty) {
      payload['timeSlotId'] = timeSlotId;
    }
    final notes = order.customerNotes;
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }

    return payload;
  }
}
