import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/order_receiver.dart';

void main() {
  ({OrderReceiver? receiver, String? error}) parse(
          {String name = 'María Gómez',
          String document = '30.123.456',
          String relationship = 'vecina'}) =>
      OrderReceiver.parse(
          name: name, document: document, relationship: relationship);

  test('normaliza el documento como el back: sin puntos ni guiones', () {
    final r = parse(document: ' 20-30123456-7 ').receiver!;
    expect(r.document, '20301234567');
    expect(parse(document: 'ab 123.456').receiver!.document, 'AB123456');
  });

  test('arma el cuerpo con los nombres del back', () {
    expect(parse().receiver!.toJson(), {
      'receiverName': 'María Gómez',
      'receiverDocument': '30123456',
      'receiverRelationship': 'vecina',
    });
  });

  test('los tres datos son obligatorios', () {
    expect(parse(name: '  ').error, contains('nombre'));
    expect(parse(document: '').error, contains('documento'));
    expect(parse(relationship: ' ').error, contains('relación'));
  });

  test('documento: de 6 a 15 letras o números y al menos un dígito', () {
    expect(parse(document: '12345').error, isNotNull);
    expect(parse(document: '1234567890123456').error, isNotNull);
    expect(parse(document: 'ABCDEFGH').error, isNotNull);
    expect(parse(document: '123456').error, isNull);
    expect(parse(document: 'AAB123456').error, isNull);
  });

  test('largos máximos del back: nombre 120 y relación 40', () {
    expect(parse(name: 'a' * 121).error, contains('120'));
    expect(parse(name: 'a' * 120).error, isNull);
    expect(parse(relationship: 'a' * 41).error, contains('40'));
  });

  test('lee el receiver de la respuesta; null si no hay o está anulado', () {
    final r = OrderReceiver.fromJson(
        {'name': 'Ana', 'document': '30123456', 'relationship': 'hermana'})!;
    expect(
        (r.name, r.document, r.relationship), ('Ana', '30123456', 'hermana'));
    expect(OrderReceiver.fromJson(null), isNull);
    expect(
        OrderReceiver.fromJson(
            {'name': null, 'document': null, 'relationship': null}),
        isNull);
  });
}
