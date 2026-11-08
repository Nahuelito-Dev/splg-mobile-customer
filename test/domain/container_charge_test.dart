import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/ui/common/formatters.dart';

/// Cargo de envases (F35): lo calcula el back; la app lo lee y lo muestra.
void main() {
  group('cotización', () {
    test('lee el cargo de envases por renglón y el total', () {
      final quote = OrderQuote.fromJson({
        'items': [
          {
            'gasCylinderId': 'g1',
            'quantity': 3,
            'unitPrice': 9500,
            'subtotal': 28500,
            'containersCharged': 2,
            'containerUnitPrice': 10000,
            'containerSubtotal': 20000,
          },
          {
            'gasCylinderId': 'g2',
            'quantity': 1,
            'unitPrice': 20000,
            'subtotal': 20000,
            'containersCharged': 1,
            'containerUnitPrice': '15000.00',
            'containerSubtotal': '15000.00',
          },
        ],
        'subtotal': 48500,
        'containerChargeAmount': 35000,
        'total': 83500,
      })!;

      expect(quote.containerChargeAmount, 35000);
      expect(quote.chargesContainers, isTrue);
      expect(quote.containersCharged, 3);
      expect(quote.lineFor('g1')!.containersCharged, 2);
      expect(quote.lineFor('g1')!.containerUnitPrice, 10000);
      expect(quote.lineFor('g1')!.containerSubtotal, 20000);
      expect(quote.lineFor('g2')!.containerUnitPrice, 15000);
      // El subtotal del renglón no lleva los envases.
      expect(quote.lineFor('g1')!.subtotal, 28500);
    });

    test('sin los campos (back anterior o sin envases): 0 y null', () {
      final quote = OrderQuote.fromJson({
        'items': [
          {
            'gasCylinderId': 'g1',
            'quantity': 2,
            'unitPrice': 9500,
            'subtotal': 19000,
          },
        ],
        'subtotal': 19000,
        'total': 19000,
      })!;

      expect(quote.containerChargeAmount, 0);
      expect(quote.chargesContainers, isFalse);
      expect(quote.containersCharged, 0);
      expect(quote.lineFor('g1')!.containersCharged, 0);
      expect(quote.lineFor('g1')!.containerUnitPrice, isNull);
      expect(quote.lineFor('g1')!.containerSubtotal, 0);
    });
  });

  group('pedido', () {
    test('lee el cargo y suma los envases de order_items', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 39000,
        'containerChargeAmount': '20000.00',
        'order_items': [
          {'quantity': 3, 'containersCharged': 2, 'containerUnitPrice': 10000},
          {'quantity': 1, 'containersCharged': 0, 'containerUnitPrice': null},
        ],
      })!;

      expect(b.containerChargeAmount, 20000);
      expect(b.containersCharged, 2);
      expect(b.chargesContainers, isTrue);
    });

    test('pedido viejo sin los campos: sin cargo', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 19000,
        'order_items': [
          {'quantity': 2},
        ],
      })!;

      expect(b.containerChargeAmount, 0);
      expect(b.containersCharged, 0);
      expect(b.chargesContainers, isFalse);
      expect(const OrderBreakdown(total: 1).chargesContainers, isFalse);
    });
  });

  group('textos', () {
    test('línea y explicación, en singular y plural', () {
      expect(containerChargeLabel(2), 'Envases (2)');
      expect(containerChargeNote(1),
          'Pedís más garrafas que los envases que tenés: se te cobra 1 envase, que queda tuyo.');
      expect(containerChargeNote(3),
          'Pedís más garrafas que los envases que tenés: se te cobran 3 envases, que quedan tuyos.');
    });
  });
}
