import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_lib/domain/discount.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:dio/dio.dart';

import '../helpers/fixtures.dart';

void main() {
  final c = cylinder(price: 1000, discounts: [
    Discount(quantity: 6, percentage: 30),
    Discount(quantity: 2, percentage: 10),
    Discount(quantity: 4, percentage: 20),
  ]);

  test('las promociones se muestran de menor a mayor', () {
    expect(Pricing.sortedDiscounts(c).map((d) => d.quantity), [2, 4, 6]);
    expect(Pricing.badge(Pricing.sortedDiscounts(c).first), '−10% x2');
  });

  test('el precio con promoción es el que manda el back, sin cuentas en la app',
      () {
    final d = Discount.fromJson(
        {'quantity': 3, 'discountPercentage': 7.5, 'unitPrice': 19749.21});
    expect(d.unitPrice, 19749.21);
    expect(
        Discount.fromJson({'quantity': 3, 'discountPercentage': 7.5}).unitPrice,
        isNull);
  });

  test('la cotización trae el porcentaje de la promoción aplicada', () {
    final q = OrderQuote.fromJson({
      'items': [
        {
          'gasCylinderId': 'g1',
          'quantity': 2,
          'unitPrice': 900,
          'subtotal': 1800,
          'discountPercentage': 10,
        },
        {
          'gasCylinderId': 'g2',
          'quantity': 1,
          'unitPrice': 500,
          'subtotal': 500
        },
      ],
      'subtotal': 2300,
      'total': 2300,
    })!;
    expect(q.lines[0].discountPercentage, 10);
    expect(q.lines[1].discountPercentage, isNull);
  });

  test('el renglón de un pedido trae lo que cobra el back', () {
    final item = OrderItem.fromJson({
      'quantity': 2,
      'subtotal': 28310,
      'gas_cylinder': cylinder(price: 14155).toJson(),
    });
    expect(item.subtotal, 28310);
  });

  group('ApiResult.fromError', () {
    test('409 de negocio en castellano conserva el mensaje del back', () {
      final r = ApiResult<void>.fromError(DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me'),
          statusCode: 409,
          data: {'message': 'Tenés pedidos en curso: esperá o cancelalos.'},
        ),
      ));
      expect(r.ok, isFalse);
      expect(r.status, 409);
      expect(r.message, 'Tenés pedidos en curso: esperá o cancelalos.');
    });

    test('sin respuesta es "sin conexión"', () {
      final r = ApiResult<void>.fromError(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError));
      expect(r.message, 'Sin conexión. Revisá tu internet.');
    });

    test('un 500 usa el texto propio, no el del servidor', () {
      final r = ApiResult<void>.fromError(DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 500,
            data: {'message': 'QueryFailedError: relation x'}),
      ));
      expect(r.message, contains('problema en el servidor'));
    });
  });
}
