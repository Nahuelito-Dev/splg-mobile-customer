import 'package:splg_lib/domain/order.dart';

/// Una página de pedidos del cliente con el total sin paginar.
class OrdersPage {
  const OrdersPage({
    required this.orders,
    required this.total,
    required this.offset,
  });

  final List<Order> orders;

  /// Total de pedidos del cliente en el back (no sólo los de esta página).
  final int total;

  /// `offset` con el que se pidió esta página.
  final int offset;

  /// Próximo `offset` a pedir: no depende de cuántos pedidos se pudieron
  /// interpretar, así la lista no se traba con un hueco.
  int get nextOffset => offset + orders.length;
}
