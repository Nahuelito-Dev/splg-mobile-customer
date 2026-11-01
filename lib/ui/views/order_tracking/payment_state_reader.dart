import 'dart:developer';

import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/domain/payment_state.dart';

/// Lee el estado del pago de Mercado Pago de un pedido. Null ante cualquier
/// falla (red, 4xx, 5xx): el seguimiento conserva lo último que supo.
typedef PaymentStateLoader = Future<PaymentState?> Function(
    String orderId, String token);

/// `GET /api/v2/orders/:id/payment` del back.
Future<PaymentState?> loadPaymentState(String orderId, String token) async {
  try {
    final response = await ApiClient()
        .get('${AppConfig.apiV2Url}orders/$orderId/payment', token);
    if (response.statusCode != 200) return null;
    return PaymentState.fromJson(response.data);
  } catch (e) {
    log('e leyendo el estado del pago: ${e.runtimeType}');
    return null;
  }
}
