import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_lib/domain/order.dart';

import '../helpers/fixtures.dart';

void main() {
  group('OrderBreakdown', () {
    test('el recargo del medio de pago es lo que sobra del total', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 17900,
        'subtotal_items': 17000,
        'zone_surcharge': {'amount': 900},
      })!;

      expect(b.zoneSurcharge, 900);
      expect(b.paymentSurcharge, 0);
    });

    test('con recargo de transferencia: total - renglones - zona', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 17380,
        'subtotal_items': 14900,
        'zone_surcharge': {'amount': 900},
      })!;

      expect(b.paymentSurcharge, 1580);
    });

    test('sin subtotal de renglones no inventa un recargo', () {
      final b = OrderBreakdown.fromJson({'total_amount': 5000})!;

      expect(b.paymentSurcharge, 0);
      expect(b.zoneSurcharge, 0);
    });

    test('sin total no hay desglose', () {
      expect(OrderBreakdown.fromJson({'subtotal_items': 1}), isNull);
      expect(OrderBreakdown.fromJson(null), isNull);
    });
  });

  group('canEditOrder', () {
    Order withDriver() => order().copyWith(deliveryId: 'd1');
    Order mp() => order().copyWith(paymentMethod: PaymentMethod.mercadoPago);

    test('pendiente, sin chofer, efectivo: sí', () {
      expect(canEditOrder(order(), null), isTrue);
      expect(canEditOrder(order(), const OrderBreakdown(total: 1000)), isTrue);
    });

    test('con chofer: no',
        () => expect(canEditOrder(withDriver(), null), isFalse));

    test('Mercado Pago: no', () => expect(canEditOrder(mp(), null), isFalse));

    test('fuera de pendiente: no', () {
      expect(canEditOrder(order(status: OrderStatus.accepted), null), isFalse);
    });

    test('cobro ya pagado: no', () {
      expect(
          canEditOrder(order(),
              const OrderBreakdown(total: 1000, paymentStatus: 'paid')),
          isFalse);
    });

    test('si el back dice editable: false, manda el back', () {
      expect(
          canEditOrder(
              order(), const OrderBreakdown(total: 1000, editable: false)),
          isFalse);
    });
  });
}
