import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_status_entry.dart';
import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/domain/rating_summary.dart';
import 'package:splg_customer/domain/reserved_orders.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/order_refund.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/rating_service.dart';
import 'package:splg_customer/services/order_document_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/live_notice.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';
import 'package:splg_customer/ui/common/transfer_payment.dart';

/// Detalle de un pedido con sus acciones según el estado: seguimiento,
/// calificar, reclamar, cancelar, modificar y repetir. Parte del pedido que
/// trae la lista y lo refresca con `GET /orders/:id`.
class OrderDetailViewModel extends LoadViewModel with TransferPayment {
  OrderDetailViewModel({required this.orderId, Order? initial})
      : order = initial;

  final String orderId;

  @override
  String get transferOrderId => orderId;
  @override
  bool get transferIsOnline =>
      order?.paymentMethod == PaymentMethod.online && !isReserved;
  @override
  bool get transferCancelled => order?.status == OrderStatus.cancelled;
  @override
  String get transferPaymentStatus => breakdown?.paymentStatus ?? 'pending';
  @override
  double? get transferAmount => breakdown?.isReservation == true
      ? breakdown?.remainingBalance ?? breakdown?.total
      : breakdown?.total ?? order?.total;

  final _history = locator<HistoryService>();
  final _nav = locator<NavigationService>();
  final _cart = locator<CartService>();
  final _sheets = locator<BottomSheetService>();
  final _dialogs = locator<DialogService>();
  final _documents = locator<OrderDocumentService>();
  final _tracking = locator<OrderTrackingService>();
  final _customer = locator<CustomerService>();
  final _ratings = locator<RatingService>();
  final _mercadoPago = locator<MercadoPagoCheckoutService>();

  Order? order;

  /// Desglose del total y estado del cobro (`GET /orders/:id`); null hasta que
  /// se lee.
  OrderBreakdown? breakdown;

  /// Devoluciones del pago (`GET /orders/:id/refunds/mine`); vacía hasta que se
  /// leen o si no hubo ninguna.
  List<OrderRefund> refunds = const [];

  /// Historial de estados (CU-170); null hasta que se lee o si no se pudo.
  List<OrderStatusEntry>? statusHistory;

  /// Calificación del repartidor (CU-065); null si no hay repartidor o no se
  /// pudo leer.
  RatingSummary? driverSummary;

  /// Último aviso en vivo (pago aprobado, reintegro, pedido modificado).
  String? liveNotice;

  StreamSubscription<OrderLiveEvent>? _liveSub;
  StreamSubscription<void>? _changesSub;
  StreamSubscription<PaymentReturn>? _paymentSub;
  bool _closed = false;

  @override
  Future<void> fetch() async {
    try {
      _apply(await _history.fetchOrderDetail(orderId));
      await _loadExtras();
    } catch (e) {
      // Con el pedido de la lista a mano se muestra eso; sin él, el error. Un
      // pedido que ya no existe no se muestra con datos viejos.
      if (order == null || _isGone(e)) rethrow;
    }
    _connectLive();
    // Volvió de Mercado Pago por deep link con esta pantalla abierta.
    _paymentSub ??= _mercadoPago.returns.listen((r) {
      if (r.orderId == null || r.orderId == orderId) unawaited(_reload());
    });
    if (_mercadoPago.takePending(orderId: orderId) != null) {
      unawaited(_reload());
    }
  }

  Future<void> _loadExtras() => Future.wait([
        _loadRefunds(),
        loadTransfer(),
        _loadHistory(),
        _loadDriverSummary(),
      ]);

  /// Escucha los avisos del back mientras el pedido siga abierto: cada uno
  /// vuelve a pedir el pedido, para que la pantalla muestre lo del back.
  void _connectLive() {
    final o = order;
    if (_closed || o == null) return;
    if (o.status == OrderStatus.delivered ||
        o.status == OrderStatus.cancelled) {
      return;
    }
    _changesSub?.cancel();
    _changesSub = _tracking.orderChanges.listen((_) => unawaited(_reload()));
    _liveSub?.cancel();
    _liveSub = _tracking.liveEvents.listen((event) {
      liveNotice = event.notice;
      notifyListeners();
    });
    _tracking.subscribeToOrder(
      orderId: orderId,
      customerId: _customer.customer.customerId,
      tokenProvider: () => _customer.token,
    );
  }

  /// Por qué no se pudo leer el historial (403, 5xx, red); null si se leyó o
  /// si el back respondió 404 (no hay nada que mostrar).
  String? historyError;

  /// Idem con la calificación del repartidor.
  String? driverSummaryError;

  /// Se está releyendo el historial o la calificación tras un error.
  bool retryingExtras = false;

  Future<void> _loadHistory() async {
    final read = await _history.fetchStatusHistory(orderId);
    if (read.ok) {
      statusHistory = read.data;
      historyError = null;
    } else if (read.status == 404) {
      statusHistory = const [];
      historyError = null;
    } else {
      historyError = read.message ?? ApiErrorText.generic;
    }
  }

  Future<void> _loadDriverSummary() async {
    final driver = breakdown?.driverUserId;
    if (driver == null || driver.isEmpty) {
      driverSummary = null;
      driverSummaryError = null;
      return;
    }
    final read = await _ratings.summaryOf(driver);
    if (read.ok) {
      driverSummary = read.data;
      driverSummaryError = null;
    } else if (read.status == 404) {
      driverSummary = null;
      driverSummaryError = null;
    } else {
      driverSummaryError = read.message ?? ApiErrorText.generic;
    }
  }

  /// Reintento de las secciones que no se pudieron leer.
  Future<void> retryExtras() async {
    if (retryingExtras) return;
    retryingExtras = true;
    notifyListeners();
    try {
      await Future.wait([_loadHistory(), _loadDriverSummary()]);
    } finally {
      retryingExtras = false;
      if (!_closed) notifyListeners();
    }
  }

  /// Renglones de la línea de tiempo: cada cambio de estado (o nota) con su
  /// fecha y, si lo hay, el motivo.
  List<({String title, String value})> get timelineRows => [
        for (final e in statusHistory ?? const <OrderStatusEntry>[])
          (
            title: e.title,
            value: e.reason == null
                ? dateTimeLabel(e.changedAt)
                : '${dateTimeLabel(e.changedAt)} · ${e.reason}',
          ),
      ];

  // ─── Reserva con seña (CU-072) ───

  /// El pedido es una reserva: espera su fecha, o ya la activó el sistema.
  bool get isReservation =>
      ReservedOrders.contains(orderId) || (breakdown?.isReservation ?? false);

  /// Todavía no se despacha: espera la fecha y la seña.
  bool get isReserved => ReservedOrders.contains(orderId);

  /// Se puede pagar la seña online: reserva con Mercado Pago, seña sin pagar y
  /// enlace vigente.
  bool get canPayDeposit =>
      order != null &&
      order!.status != OrderStatus.cancelled &&
      (breakdown?.paysWithMercadoPago ?? false) &&
      (breakdown?.depositPending ?? false) &&
      (breakdown?.paymentUrl ?? '').isNotEmpty;

  /// Filas de la reserva: fecha, seña, estado de la seña y saldo.
  List<({String title, String value})> get reservationRows {
    final b = breakdown;
    if (!isReservation || b == null) return const [];
    final parsed =
        b.scheduledDate == null ? null : DateTime.tryParse(b.scheduledDate!);
    return [
      if (parsed != null)
        (title: 'Fecha de entrega:', value: dateLabel(parsed)),
      (
        title: 'Seña:',
        value: b.depositAmount <= 0
            ? 'Sin seña'
            : '${money.format(b.depositAmount)} · ${b.depositPaid ? 'pagada' : 'pendiente'}',
      ),
      if (b.remainingBalance != null)
        (title: 'Saldo al entregar:', value: money.format(b.remainingBalance!)),
    ];
  }

  /// Se está abriendo el pago de la seña, o el checkout sigue abierto y
  /// todavía no se releyó el pedido: el botón no abre otro.
  bool payingDeposit = false;

  /// Abre el pago de la seña (Checkout Pro) con el enlace pendiente del back
  /// (el back devuelve siempre la misma preferencia mientras siga vigente). El
  /// resultado llega por deep link y lo confirma el webhook: acá sólo se
  /// relee el pedido.
  Future<void> payDeposit() async {
    final url = breakdown?.paymentUrl;
    if (payingDeposit || !canPayDeposit || url == null) return;
    payingDeposit = true;
    notifyListeners();
    try {
      final opened = await _mercadoPago.open(url);
      if (_closed) return;
      if (!opened) {
        await _dialogs.showDialog(
          title: 'No se pudo abrir el pago',
          description:
              'No pudimos abrir Mercado Pago. Probá de nuevo en un rato.',
          buttonTitle: 'Aceptar',
        );
        return;
      }
      // Sigue bloqueado hasta que el cliente vuelve de Mercado Pago.
      await _paymentReturned();
    } finally {
      if (!_closed) {
        await _reload();
        payingDeposit = false;
        if (!_closed) notifyListeners();
      }
    }
  }

  /// Cuánto se espera, como mucho, la vuelta del checkout. En iOS cerrar el
  /// SFSafariViewController sin pagar no avisa nada (ni deep link ni cambio de
  /// ciclo de vida): pasado este plazo se relee el pedido y, si la seña sigue
  /// pendiente, se puede volver a abrir (el back devuelve el mismo enlace).
  @visibleForTesting
  static Duration paymentReturnTimeout = const Duration(seconds: 30);

  /// La vuelta del checkout: por deep link, al volver la app a primer plano
  /// (Custom Tabs en Android) o pasado [paymentReturnTimeout].
  Future<void> _paymentReturned() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final sub = _mercadoPago.returns.listen((_) => finish());
    final observer = _ResumeObserver(finish);
    WidgetsBinding.instance.addObserver(observer);
    final timer = Timer(paymentReturnTimeout, finish);
    _cancelPaymentWait = finish;
    return done.future.whenComplete(() {
      timer.cancel();
      sub.cancel();
      WidgetsBinding.instance.removeObserver(observer);
      _cancelPaymentWait = null;
    });
  }

  void Function()? _cancelPaymentWait;

  void _apply(OrderDetail detail) {
    order = detail.order;
    breakdown = detail.breakdown;
  }

  /// Sólo un pedido cancelado, o uno express que pasó al reparto común, puede
  /// tener devolución. Si no se puede leer se queda con lo que ya mostraba.
  Future<void> _loadRefunds() async {
    final o = order;
    if (o == null) return;
    if (o.status != OrderStatus.cancelled && !expressDegraded) {
      refunds = const [];
      return;
    }
    final read = await _history.fetchOrderRefunds(orderId);
    if (read != null) refunds = read;
  }

  static bool _isGone(Object e) => e is LoadFailure && !e.retryable;

  Future<void> _reload() async {
    if (_closed) return;
    try {
      _apply(await _history.fetchOrderDetail(orderId));
      await _loadExtras();
    } catch (e) {
      if (_isGone(e)) {
        order = null;
        loadError = LoadViewModel.errorText(e);
        canRetry = false;
      }
      // Cualquier otra falla: se queda con lo que ya tenía.
    }
    if (!_closed) notifyListeners();
  }

  bool get _active => order != null && isActive(order!.status);

  bool get canTrack =>
      order?.status == OrderStatus.accepted ||
      order?.status == OrderStatus.outForDelivery;
  bool get canCancel => order?.status == OrderStatus.pending;
  bool get canModify => order != null && canEditOrder(order!, breakdown);
  bool get canRate => order?.status == OrderStatus.delivered;
  bool get canClaim => order?.status == OrderStatus.delivered;
  bool get canRepeat => order != null && !_active;
  bool get canChangeAddress =>
      order != null && !saving && canChangeOrderAddress(order!, breakdown);
  bool get canSetReceiver =>
      order != null && !saving && canSetOrderReceiver(order!);

  /// El remito sale siempre que el pedido exista.
  bool get canDownloadRemito => order != null;

  /// El recibo sólo con el pago acreditado y el pedido sin cancelar (si no, el
  /// back responde 409).
  bool get canDownloadRecibo =>
      order != null &&
      order!.status != OrderStatus.cancelled &&
      breakdown?.paymentStatus == 'paid';

  /// Documento que se está bajando; null si no hay descarga en curso.
  OrderDocument? downloading;

  /// El pedido es express, o lo fue y pasó al reparto común.
  /// El pedido cobró envases (el cliente pidió más garrafas que las vacías que
  /// tenía para canjear).
  bool get chargesContainers => breakdown?.chargesContainers ?? false;

  bool get isExpress => breakdown?.isExpress ?? false;
  bool get expressDegraded => breakdown?.expressDegraded ?? false;

  /// El cobro ya se hizo por una pasarela o transferencia.
  bool get paidOnline =>
      breakdown?.paymentStatus == 'paid' &&
      order?.paymentMethod != PaymentMethod.cash;
  OrderReceiver? get receiver => breakdown?.receiver;

  /// Una fila por devolución: qué se devuelve y en qué estado está.
  List<({String title, String value})> get refundRows => [
        for (final r in refunds)
          (
            title: r.expressSurchargeOnly
                ? 'Reintegro del recargo express:'
                : 'Reintegro:',
            value: switch (r.status) {
              RefundStatus.pending => '${money.format(r.amount)} · en trámite',
              RefundStatus.succeeded => r.completedAt == null
                  ? '${money.format(r.amount)} · acreditado'
                  : '${money.format(r.amount)} · acreditado el ${dateLabel(r.completedAt!)}',
              RefundStatus.failed =>
                '${money.format(r.amount)} · no se pudo acreditar todavía; lo estamos revisando',
            },
          ),
      ];

  /// Hay un cambio (dirección) guardándose: no se lanza otro encima.
  bool saving = false;

  /// Elige otra de las direcciones del cliente para este pedido (CU-127). El
  /// back recalcula el total y rechaza lo que no corresponde (ya salió, pago en
  /// línea con otro recargo, fuera de cobertura): ese texto se muestra tal cual.
  Future<void> changeAddress() async {
    final o = order;
    if (o == null || saving) return;
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Elegí la dirección de entrega',
      data: {'selectedId': o.address?.addressId},
    );
    if (response?.confirmed != true || response?.data is! Address) return;
    final chosen = response!.data as Address;
    if (chosen.addressId == o.address?.addressId) return;

    saving = true;
    notifyListeners();
    final result = await _history.changeOrderAddress(orderId, chosen.addressId);
    saving = false;
    if (result.success) {
      // Lo que devolvió el back manda; la relectura sólo completa el desglose
      // y, si falla, no deshace el cambio.
      final updated = result.order;
      if (updated != null) order = updated;
      notifyListeners();
      await _reload();
      final now = order ?? updated ?? o;
      await _dialogs.showDialog(
        title: 'Dirección actualizada',
        description:
            'Tu pedido se entrega en ${now.address?.streetName ?? chosen.streetName}. '
            'El total ahora es ${money.format(now.total)}.',
        buttonTitle: 'Aceptar',
      );
      return;
    }
    notifyListeners();
    await _dialogs.showDialog(
      title: 'No pudimos cambiar la dirección',
      description: result.message,
      buttonTitle: 'Aceptar',
    );
    // El pedido pudo cambiar de estado (ya salió): se relee.
    if (result.rejected) await _reload();
  }

  /// Indica quién recibe el pedido (CU-128), desde la hoja del receptor.
  Future<void> editReceiver() async {
    if (order == null || saving) return;
    await _sheets.showCustomSheet(
      variant: BottomSheetType.receiver,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId, 'receiver': receiver},
    );
    // También tras un rechazo: el pedido pudo cambiar (ya se entregó).
    await _reload();
  }

  /// Baja el PDF y lo abre en la hoja nativa. Mientras baja no se lanza otra
  /// descarga; un error del back se muestra tal cual.
  Future<void> openDocument(OrderDocument doc) async {
    if (downloading != null) return;
    downloading = doc;
    notifyListeners();
    final result = await _documents.open(orderId, doc);
    downloading = null;
    notifyListeners();
    if (!result.ok) {
      await _dialogs.showDialog(
        title: 'No pudimos abrir el ${doc.label.toLowerCase()}',
        description: result.message,
        buttonTitle: 'Aceptar',
      );
    }
  }

  Future<void> track() async {
    await _nav.navigateToOrderTrackingView(orderId: orderId);
    await _reload();
    // El seguimiento cortó la conexión al cerrarse.
    _connectLive();
  }

  Future<void> cancel() async {
    final cancelled = await _nav.navigateToCancelOrderView(orderId: orderId);
    if (cancelled == true) await _reload();
  }

  /// Abre la edición del pedido y, al volver, lo relee: haya guardado o no, el
  /// pedido pudo cambiar (o ya no ser editable porque lo tomó un repartidor).
  Future<void> modify() async {
    final o = order;
    if (o == null) return;
    await _nav.navigateToEditOrderView(order: o, breakdown: breakdown);
    await _reload();
  }

  /// Repetir: el carrito del back pasa a tener los ítems de este pedido y se
  /// sigue por el carrito, donde el cliente ve precios y disponibilidad de hoy.
  Future<void> repeat() async {
    final o = order;
    if (o == null) return;
    final r = await _cart.replaceWith(o.items);
    if (!r.ok) {
      await _dialogs.showDialog(
        title: 'No pudimos armar el carrito',
        description: r.message,
        buttonTitle: 'Aceptar',
      );
      return;
    }
    await _nav.navigateToCartView();
  }

  @override
  void dispose() {
    _closed = true;
    _cancelPaymentWait?.call();
    _liveSub?.cancel();
    _changesSub?.cancel();
    _paymentSub?.cancel();
    _tracking.disconnect();
    super.dispose();
  }

  Future<void> rate() async {
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.rateDriver,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId, 'driverName': order?.deliveryName},
    );
    if (response?.confirmed == true) {
      await _dialogs.showDialog(
        title: '¡Gracias por calificar!',
        description: 'Tu opinión nos ayuda a mejorar el servicio.',
        buttonTitle: 'Aceptar',
      );
    }
  }

  Future<void> claim() async {
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.claim,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId},
    );
    if (response?.confirmed == true) {
      await _dialogs.showDialog(
        title: 'Reclamo enviado',
        description:
            'Recibimos tu reclamo. Lo vamos a revisar y te contactamos.'
            '${response?.data is String ? '\n\n${response!.data}' : ''}',
        buttonTitle: 'Aceptar',
      );
    }
  }
}

/// Avisa cuando la app vuelve a primer plano después de haber salido (el
/// checkout en Custom Tabs la manda a segundo plano).
class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);

  final void Function() onResumed;
  bool _left = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _left = true;
    } else if (state == AppLifecycleState.resumed && _left) {
      onResumed();
    }
  }
}
