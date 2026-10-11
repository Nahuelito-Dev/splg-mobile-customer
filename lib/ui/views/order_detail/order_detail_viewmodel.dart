import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
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

  @override
  Future<void> fetch() async {
    try {
      order = await _history.fetchOrder(orderId);
    } catch (e) {
      // Con el pedido de la lista a mano se muestra eso; sin él, el error.
      if (order == null) rethrow;
    }
  }

  Future<void> _reload() async {
    try {
      order = await _history.fetchOrder(orderId);
    } catch (_) {
      // Se queda con lo que ya tenía.
    }
    notifyListeners();
  }

  bool get _active => order != null && isActive(order!.status);

  bool get canTrack =>
      order?.status == OrderStatus.accepted ||
      order?.status == OrderStatus.outForDelivery;
  bool get canCancel => order?.status == OrderStatus.pending;
  bool get canModify => order?.status == OrderStatus.pending;
  bool get canRate => order?.status == OrderStatus.delivered;
  bool get canClaim => order?.status == OrderStatus.delivered;
  bool get canRepeat => order != null && !_active;

  Future<void> track() async {
    await _nav.navigateToOrderTrackingView(orderId: orderId);
    await _reload();
  }

  Future<void> cancel() async {
    final cancelled = await _nav.navigateToCancelOrderView(orderId: orderId);
    if (cancelled == true) await _reload();
  }

  void modify() {
    final o = order;
    if (o == null) return;
    _cart.setOrder(o);
    _cart.startEditingOrder(o.id);
    _nav.navigateToCheckoutView();
  }

  void repeat() {
    final o = order;
    if (o == null) return;
    _cart.setOrder(o);
    _cart.clearEditingOrder();
    _nav.navigateToCheckoutView();
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
            'Recibimos tu reclamo. Lo vamos a revisar y te contactamos.',
        buttonTitle: 'Aceptar',
      );
    }
  }
}
