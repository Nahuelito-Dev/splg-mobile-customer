import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/delivery_options.dart';

void main() {
  const raw = {
    'addressId': 'a1',
    'options': [
      {
        'mode': 'standard',
        'available': true,
        'reason': null,
        'message': null,
        'surchargeAmount': 0,
        'estimatedMinutes': 180,
      },
      {
        'mode': 'express',
        'available': false,
        'reason': 'no_motorcycle_driver',
        'message': 'No hay un chofer en moto disponible cerca',
        'surchargeAmount': 350.5,
        'estimatedMinutes': 45,
      },
    ],
  };

  test('lee las dos modalidades con recargo, demora y motivo', () {
    final options = DeliveryOptions.fromJson(raw)!;

    final standard = options.optionFor(DeliveryMode.standard)!;
    expect((standard.available, standard.estimatedMinutes), (true, 180));
    expect(standard.unavailableText, isNull);

    final express = options.optionFor(DeliveryMode.express)!;
    expect(express.available, isFalse);
    expect(express.surchargeAmount, 350.5);
    expect(express.reason, 'no_motorcycle_driver');
    expect(express.unavailableText,
        'No hay un repartidor en moto disponible cerca.');
  });

  test('sin lista de opciones no hay nada que mostrar', () {
    expect(DeliveryOptions.fromJson({'addressId': 'a1'}), isNull);
    expect(DeliveryOptions.fromJson(null), isNull);
    expect(const DeliveryOptions([]).hasExpress, isFalse);
  });

  test('cada motivo del back tiene su texto en castellano', () {
    for (final reason in [
      'disabled',
      'no_location',
      'out_of_coverage',
      'out_of_hours',
      'no_motorcycle_driver',
    ]) {
      final text = expressUnavailableText(reason, 'backend message');
      expect(text, isNot('backend message'), reason: reason);
      expect(text, endsWith('.'), reason: reason);
    }
  });

  test('un motivo desconocido usa el mensaje del back, y sin él uno propio',
      () {
    expect(expressUnavailableText('otro', ' Sin motos hoy '), 'Sin motos hoy');
    expect(expressUnavailableText('otro'), contains('no está disponible'));
  });

  test('deliveryMode: sólo "express" es express', () {
    expect(DeliveryMode.fromWire('express'), DeliveryMode.express);
    expect(DeliveryMode.fromWire('standard'), DeliveryMode.standard);
    expect(DeliveryMode.fromWire(null), DeliveryMode.standard);
    expect(DeliveryMode.express.wire, 'express');
  });
}
