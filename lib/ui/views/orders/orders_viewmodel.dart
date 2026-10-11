import 'package:flutter/foundation.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/order.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Mis pedidos: lista propia con paginación (`limit`/`offset` + `total`). No
/// comparte la lista del inicio, que el polling recorta y reemplaza.
class OrdersViewModel extends LoadViewModel {
  final _history = locator<HistoryService>();
  final _nav = locator<NavigationService>();

  static const pageSize = 20;

  List<Order> orders = const [];

  /// Total de pedidos del cliente según el back.
  int total = 0;

  bool loadingMore = false;

  /// Falló la última carga de más (se reintenta con `loadMore(retry: true)`).
  String? moreError;

  /// Próximo `offset` que pide el back (no la cantidad de pedidos deduplicados:
  /// con un hueco o un repetido la lista no se traba).
  int _nextOffset = 0;

  /// Época de la lista: cada carga inicial la incrementa y las respuestas de
  /// un `loadMore` de una época vieja se descartan.
  int _epoch = 0;

  bool _lastPageHadItems = true;

  bool get hasMore => _nextOffset < total && _lastPageHadItems;

  @override
  Future<void> fetch() async {
    final epoch = ++_epoch;
    loadingMore = false;
    final page = await _history.fetchOrdersPage(limit: pageSize);
    if (epoch != _epoch) return;
    _apply(page.orders, page.total, page.nextOffset, replace: true);
    moreError = null;
    loadingMore = false;
  }

  void _apply(List<Order> page, int newTotal, int nextOffset,
      {required bool replace}) {
    if (replace) {
      orders = page;
    } else {
      final known = {for (final o in orders) o.id};
      orders = [...orders, ...page.where((o) => !known.contains(o.id))];
    }
    total = newTotal;
    _nextOffset = nextOffset;
    _lastPageHadItems = page.isNotEmpty;
  }

  /// Trae la página siguiente y la agrega (sin repetir pedidos). Tras un error
  /// no se reintenta sola (por scroll): sólo con `retry: true`.
  Future<void> loadMore({bool retry = false}) async {
    if (loadingMore || !hasMore || isBusy) return;
    if (moreError != null && !retry) return;
    final epoch = _epoch;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      final page =
          await _history.fetchOrdersPage(limit: pageSize, offset: _nextOffset);
      if (epoch != _epoch) return;
      _apply(page.orders, page.total, page.nextOffset, replace: false);
    } catch (e) {
      if (epoch != _epoch) return;
      debugPrint('No se pudo traer más pedidos: $e');
      moreError = LoadViewModel.errorText(e);
    }
    loadingMore = false;
    notifyListeners();
  }

  /// Vuelve a pedir la primera página sin mostrar la carga. Si falla, deja la
  /// lista como estaba.
  Future<void> refresh() async {
    final epoch = ++_epoch;
    // Un `loadMore` en vuelo queda descartado por la época: su indicador se
    // apaga acá, también si este refresco falla.
    loadingMore = false;
    try {
      final page = await _history.fetchOrdersPage(limit: pageSize);
      if (epoch != _epoch) return;
      _apply(page.orders, page.total, page.nextOffset, replace: true);
      moreError = null;
      loadingMore = false;
    } catch (e) {
      debugPrint('No se pudo refrescar Mis pedidos: $e');
    }
    notifyListeners();
  }

  Future<void> open(Order order) async {
    await _nav.navigateToOrderDetailView(orderId: order.id, order: order);
    await refresh();
  }
}
