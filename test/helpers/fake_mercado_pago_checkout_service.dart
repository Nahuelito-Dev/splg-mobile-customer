import 'dart:async';

import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';

/// Checkout de Mercado Pago sin navegador: registra las URLs abiertas y deja
/// que el test dispare la vuelta por deep link.
class FakeMercadoPagoCheckoutService implements MercadoPagoCheckoutService {
  final opened = <String>[];
  bool canOpen = true;
  final _returns = StreamController<PaymentReturn>.broadcast();

  @override
  Stream<PaymentReturn> get returns => _returns.stream;

  @override
  PaymentReturn? pending;
  var started = 0;

  @override
  PaymentReturn? takePending({String? orderId}) {
    final p = pending;
    if (p == null) return null;
    if (orderId != null && p.orderId != null && p.orderId != orderId) {
      return null;
    }
    pending = null;
    return p;
  }

  @override
  Future<void> start() async => started++;

  void comeBack(PaymentReturn back) => _returns.add(back);

  @override
  Future<bool> open(String paymentUrl) async {
    opened.add(paymentUrl);
    return canOpen;
  }
}
