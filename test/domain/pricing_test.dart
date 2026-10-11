import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_result.dart';
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

  test('toma la promoción de mayor umbral alcanzado', () {
    expect(Pricing.applied(c, 1), isNull);
    expect(Pricing.applied(c, 2)!.percentage, 10);
    expect(Pricing.applied(c, 5)!.percentage, 20);
    expect(Pricing.applied(c, 9)!.percentage, 30);
  });

  test('subtotal y total', () {
    final items = [
      OrderItem(cylinder: c, quantity: 4),
      OrderItem(cylinder: cylinder(id: 'x', price: 500), quantity: 1),
    ];
    expect(Pricing.subtotal(items.first), closeTo(3200, 0.001));
    expect(Pricing.total(items), closeTo(3700, 0.001));
  });

  test('las promociones se muestran de menor a mayor', () {
    expect(Pricing.sortedDiscounts(c).map((d) => d.quantity), [2, 4, 6]);
    expect(Pricing.badge(Pricing.sortedDiscounts(c).first), '−10% x2');
  });

  test('sin promociones el subtotal es precio x cantidad', () {
    expect(
        Pricing.subtotal(
            OrderItem(cylinder: cylinder(price: 700), quantity: 3)),
        2100);
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
