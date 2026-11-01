import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/payment_state.dart';

void main() {
  group('PaymentState.fromJson (GET /api/v2/orders/:id/payment)', () {
    test('lee el estado, el motivo, el texto del back y el reintento', () {
      final state = PaymentState.fromJson({
        'orderId': 'o1',
        'paymentStatus': 'rejected',
        'paymentStatusDetail': 'cc_rejected_insufficient_amount',
        'paymentStatusLabel': 'Fondos insuficientes en el medio de pago',
        'canRetry': true,
        'paymentUrl': 'https://mp.test/checkout',
      })!;

      expect(state.status, 'rejected');
      expect(state.detail, 'cc_rejected_insufficient_amount');
      expect(state.label, 'Fondos insuficientes en el medio de pago');
      expect(state.hasPayment, isTrue);
      expect(state.wasRejected, isTrue);
      expect(state.canPay, isTrue);
      expect(state.paymentUrl, 'https://mp.test/checkout');
    });

    test('sin pagos de Mercado Pago: nada que mostrar ni pagar', () {
      final state = PaymentState.fromJson({
        'paymentStatus': null,
        'paymentStatusLabel': null,
        'canRetry': false,
        'paymentUrl': null,
      })!;

      expect(state.hasPayment, isFalse);
      expect(state.canPay, isFalse);
    });

    test('canRetry sin enlace no habilita el botón', () {
      final state = PaymentState.fromJson({
        'paymentStatus': 'rejected',
        'paymentStatusLabel': 'Rechazado por el banco',
        'canRetry': true,
        'paymentUrl': null,
      })!;

      expect(state.canPay, isFalse);
    });

    test('un enlace sin canRetry (el back dice que no) no habilita el botón',
        () {
      final state = PaymentState.fromJson({
        'paymentStatus': 'in_process',
        'paymentStatusLabel': 'Pago en revisión',
        'canRetry': false,
        'paymentUrl': 'https://mp.test/checkout',
      })!;

      expect(state.canPay, isFalse);
      expect(state.wasRejected, isFalse);
    });

    test('lo que no es un objeto se descarta', () {
      expect(PaymentState.fromJson(null), isNull);
      expect(PaymentState.fromJson('x'), isNull);
      expect(PaymentState.fromJson(const <dynamic>[]), isNull);
    });

    test('cancelado también cuenta como no completado (reintento)', () {
      expect(
        PaymentState.fromJson({
          'paymentStatus': 'cancelled',
          'paymentStatusLabel': 'Pago cancelado',
        })!
            .wasRejected,
        isTrue,
      );
    });
  });
}
