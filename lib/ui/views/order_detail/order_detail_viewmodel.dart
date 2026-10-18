import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Detalle de un pedido con sus acciones según el estado: seguimiento,
/// calificar, reclamar, cancelar, modificar y repetir. Parte del pedido que
/// trae la lista y lo refresca con `GET /orders/:id`.
class OrderDetailViewModel extends LoadViewModel {
  OrderDetailViewModel({required this.orderId, Order? initial})
      : order = initial;

  final String orderId;

  final _history = locator<HistoryService>();
  final _nav = locator<NavigationService>();
  final _cart = locator<CartService>();
  final _sheets = locator<BottomSheetService>();
  final _dialogs = locator<DialogService>();

  Order? order;

  /// Desglose del total y estado del cobro (`GET /orders/:id`); null hasta que
  /// se lee.
  OrderBreakdown? breakdown;

  @override
  Future<void> fetch() async {
    try {
      _apply(await _history.fetchOrderDetail(orderId));
    } catch (e) {
      // Con el pedido de la lista a mano se muestra eso; sin él, el error. Un
      // pedido que ya no existe no se muestra con datos viejos.
      if (order == null || _isGone(e)) rethrow;
    }
  }

  void _apply(OrderDetail detail) {
    order = detail.order;
    breakdown = detail.breakdown;
  }

  static bool _isGone(Object e) => e is LoadFailure && !e.retryable;

  Future<void> _reload() async {
    try {
      _apply(await _history.fetchOrderDetail(orderId));
    } catch (e) {
      if (_isGone(e)) {
        order = null;
        loadError = LoadViewModel.errorText(e);
        canRetry = false;
      }
      // Cualquier otra falla: se queda con lo que ya tenía.
    }
    notifyListeners();
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

  /// El pedido es express, o lo fue y pasó al reparto común.
  bool get isExpress => breakdown?.isExpress ?? false;
  bool get expressDegraded => breakdown?.expressDegraded ?? false;

  /// El cobro ya se hizo por una pasarela o transferencia.
  bool get paidOnline =>
      breakdown?.paymentStatus == 'paid' &&
      order?.paymentMethod != PaymentMethod.cash;
  OrderReceiver? get receiver => breakdown?.receiver;

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

  Future<void> track() async {
    await _nav.navigateToOrderTrackingView(orderId: orderId);
    await _reload();
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
