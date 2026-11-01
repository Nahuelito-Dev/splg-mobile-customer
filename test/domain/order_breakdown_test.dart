import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/delivery_options.dart';
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

    test('el recargo de pago es el que informa el back, no se deduce del total',
        () {
      final informado = OrderBreakdown.fromJson({
        'total_amount': 17380,
        'subtotal_items': 14900,
        'zone_surcharge': {'amount': 900},
        'paymentSurchargeAmount': 1580,
      })!;
      final sinInformar = OrderBreakdown.fromJson({
        'total_amount': 17380,
        'subtotal_items': 14900,
        'zone_surcharge': {'amount': 900},
      })!;

      expect(informado.paymentSurcharge, 1580);
      expect(sinInformar.paymentSurcharge, 0);
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

  group('express y receptor', () {
    test('un express: el recargo está en el total y no es recargo de pago', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 12350,
        'subtotal_items': 10000,
        'zone_surcharge': {'amount': 0},
        'deliveryMode': 'express',
        'expressSurchargeAmount': 2350,
      })!;

      expect(b.isExpress, isTrue);
      expect(b.expressSurchargeInTotal, 2350);
      expect(b.paymentSurcharge, 0);
      expect(b.expressDegraded, isFalse);
    });

    test('pasó al reparto común: el recargo se conserva pero ya no suma', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 10000,
        'subtotal_items': 10000,
        'deliveryMode': 'standard',
        'expressSurchargeAmount': 2350,
        'expressDegradedAt': '2026-10-18T15:00:00.000Z',
      })!;

      expect(b.isExpress, isFalse);
      expect(b.expressDegraded, isTrue);
      expect(b.expressSurchargeAmount, 2350);
      expect(b.expressSurchargeInTotal, 0);
      expect(b.paymentSurcharge, 0);
    });

    test('lee quién recibe; sin él, null', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 1000,
        'receiver': {
          'name': 'María',
          'document': '30123456',
          'relationship': 'vecina'
        },
      })!;
      expect(b.receiver!.name, 'María');
      expect(
          OrderBreakdown.fromJson({'total_amount': 1000, 'receiver': null})!
              .receiver,
          isNull);
    });
  });

  group('canChangeOrderAddress / canSetOrderReceiver', () {
    test('pendiente o aceptado: se puede cambiar la dirección', () {
      const known = OrderBreakdown(total: 1);
      expect(canChangeOrderAddress(order(), known), isTrue);
      expect(canChangeOrderAddress(order(status: OrderStatus.accepted), known),
          isTrue);
    });

    test('sin el desglose no se sabe si es express: no se ofrece', () {
      expect(canChangeOrderAddress(order(), null), isFalse);
    });

    test('en camino, entregado o cancelado: no', () {
      for (final s in [
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled
      ]) {
        expect(
            canChangeOrderAddress(
                order(status: s), const OrderBreakdown(total: 1)),
            isFalse);
      }
    });

    test('express: no cambia de dirección', () {
      const express =
          OrderBreakdown(total: 1, deliveryMode: DeliveryMode.express);
      expect(canChangeOrderAddress(order(), express), isFalse);
    });

    test('quién recibe: hasta que se entrega o se cancela', () {
      expect(canSetOrderReceiver(order()), isTrue);
      expect(canSetOrderReceiver(order(status: OrderStatus.outForDelivery)),
          isTrue);
      expect(
          canSetOrderReceiver(order(status: OrderStatus.delivered)), isFalse);
      expect(
          canSetOrderReceiver(order(status: OrderStatus.cancelled)), isFalse);
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
