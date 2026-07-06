import 'package:jennygas_lib/domain/order.dart';

/// Resultado de crear un pedido.
///
/// Además de indicar éxito y devolver el [Order] creado, propaga el
/// `paymentUrl` (init_point de Checkout Pro de MercadoPago) que el backend
/// incluye en la respuesta cuando el pedido se crea con
/// `paymentMethod: mercadopago`. Para `cash`/`transfer` viene null.
class CreateOrderResult {
  const CreateOrderResult({
    required this.success,
    this.order,
    this.paymentUrl,
  });

  final bool success;
  final Order? order;
  final String? paymentUrl;
}
