import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/payment_term.dart';
import 'package:splg_customer/ui/views/help/help_view.dart';
import 'package:splg_customer/ui/common/formatters.dart';

Map<String, dynamic> quoteJson(String method, double pct, double surcharge) => {
      'items': [
        {
          'gasCylinderId': 'g1',
          'quantity': 2,
          'unitPrice': 9000,
          'subtotal': 18000
        }
      ],
      'subtotal': 18000,
      'zoneSurcharge': 0,
      'paymentMethod': method,
      'paymentSurcharge': surcharge,
      'paymentSurchargePercentage': pct,
      'deposit': 0,
      'total': 18000 + surcharge,
      'balance': 18000 + surcharge,
    };

void main() {
  group(
      'recargo por medio de pago en la cotización (nada se calcula en la app)',
      () {
    for (final c in [
      ('transfer', 0.0, 0.0, 'Recargo por transferencia (0 %)'),
      ('transfer', 10.0, 1800.0, 'Recargo por transferencia (10 %)'),
      ('mercadopago', 7.5, 1350.0, 'Recargo por Mercado Pago (7,5 %)'),
      ('mercadopago', 12.34, 2221.2, 'Recargo por Mercado Pago (12,34 %)'),
      ('cash', 2.0, 360.0, 'Recargo por efectivo (2 %)'),
    ]) {
      test('${c.$1} al ${c.$2} %', () {
        final q = OrderQuote.fromJson(quoteJson(c.$1, c.$2, c.$3))!;
        expect(q.paymentSurchargePercentage, c.$2);
        expect(q.paymentSurcharge, c.$3);
        expect(q.total, 18000 + c.$3);
        expect(
            paymentSurchargeLabel(
                q.paymentMethod, q.paymentSurchargePercentage),
            c.$4);
      });
    }

    test('un back que no informa el porcentaje: el texto no lo inventa', () {
      final json = quoteJson('transfer', 10, 1800)
        ..remove('paymentSurchargePercentage')
        ..remove('paymentMethod');
      final q = OrderQuote.fromJson(json)!;
      expect(q.paymentSurchargePercentage, isNull);
      expect(
          paymentSurchargeLabel(q.paymentMethod, q.paymentSurchargePercentage),
          'Recargo por medio de pago');
    });
  });

  group('percentLabel', () {
    test('sin ceros de más y con coma', () {
      expect(percentLabel(10), '10');
      expect(percentLabel(7.5), '7,5');
      expect(percentLabel(12.34), '12,34');
      expect(percentLabel(0), '0');
      expect(percentLabel(30), '30');
      expect(percentLabel(0.05), '0,05');
    });
  });

  group('recargo en el pedido (GET /orders/:id)', () {
    test('toma el monto y el % que informa el back', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 19350,
        'subtotal_items': 18000,
        'zone_surcharge': {'amount': 0},
        'paymentSurchargeAmount': 1350,
        'paymentSurchargePercentage': 7.5,
      })!;
      expect(b.paymentSurcharge, 1350);
      expect(b.paymentSurchargePercentage, 7.5);
    });

    test('con 0 % informado no se deduce nada del total', () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 18000,
        'subtotal_items': 18000,
        'paymentSurchargeAmount': 0,
        'paymentSurchargePercentage': 0,
      })!;
      expect(b.paymentSurcharge, 0);
    });

    test('un pedido anterior (porcentaje null) conserva el monto informado',
        () {
      final b = OrderBreakdown.fromJson({
        'total_amount': 19800,
        'subtotal_items': 18000,
        'paymentSurchargeAmount': 1800,
        'paymentSurchargePercentage': null,
      })!;
      expect(b.paymentSurcharge, 1800);
      expect(b.paymentSurchargePercentage, isNull);
    });
  });

  group('medios de pago con su recargo (los informa el back)', () {
    final terms = PaymentTerm.listFromJson([
      {'name': 'Efectivo', 'key': 'CASH', 'surcharge': 0},
      {'name': 'Transferencia', 'key': 'TRANSFER', 'surcharge': 7.5},
      {'name': 'Mercado Pago', 'key': 'MERCADOPAGO', 'surcharge': 10},
    ]);

    test('se lee la lista y cada medio con su porcentaje', () {
      expect(terms.length, 3);
      expect(PaymentTerm.of(terms, 'TRANSFER')!.percentageLabel, '7,5 %');
      expect(PaymentTerm.of(terms, 'CASH')!.hasSurcharge, isFalse);
      expect(PaymentTerm.of(terms, 'NADA'), isNull);
    });

    test('lo ilegible se descarta', () {
      expect(PaymentTerm.listFromJson(null), isEmpty);
      expect(
          PaymentTerm.listFromJson([
            {'key': 'CASH'},
            'x'
          ]),
          isEmpty);
    });

    test('la ayuda menciona sólo los recargos que el back informa', () {
      expect(paymentHelpBody(terms),
          'Efectivo al recibir, transferencia (con un 7,5 % de recargo) y Mercado Pago (con un 10 % de recargo).');
      expect(paymentHelpBody(const []),
          'Efectivo al recibir, transferencia y Mercado Pago.');
      expect(
          paymentHelpBody(PaymentTerm.listFromJson([
            {'name': 'T', 'key': 'TRANSFER', 'surcharge': 0},
            {'name': 'M', 'key': 'MERCADOPAGO', 'surcharge': 0},
          ])),
          'Efectivo al recibir, transferencia y Mercado Pago.');
    });
  });
}
