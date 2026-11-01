import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El precio, el subtotal, el recargo y el total los calcula el back; la app
/// sólo los muestra. Si alguien vuelve a hacer una cuenta de plata en `lib/`
/// (multiplicar o dividir un monto, aplicar un porcentaje, restar o sumar
/// montos, acumularlos), este test falla.

const _monto =
    r'(?:[Pp]rice|[Ss]ubtotal|[Tt]otal|[Aa]mount|[Ss]urcharge|[Bb]alance|[Dd]eposit)';
const _operando = r'[\w.!?()\[\]]*';

final _cuentas = <String, RegExp>{
  'monto × o ÷ algo': RegExp('\\b$_operando$_monto\\w*!?\\s*[*/]'),
  'algo × o ÷ monto': RegExp('[*/]\\s*\\(?\\s*$_operando$_monto\\b'),
  'cuenta con porcentaje': RegExp(
      r'[Pp]ercentage\w*!?\s*[*/]|[*/]\s*\(?\s*[\w.!?]*[Pp]ercentage|\b1\s*-\s*\(?[\w.!?]*[Pp]ercentage|\b100\s*-\s*[\w.!?]*[Pp]ercentage'),
  'resta o suma de montos': RegExp(
      '$_monto\\w*!?\\s*[-+]\\s*\\(?\\s*$_operando(?:$_monto|[Ii]tems\\b)'),
  'acumula montos': RegExp('\\.fold\\([^;]*$_monto'),
};

/// Las cuentas de plata que hay en [codigo] (sin comentarios ni saltos de
/// línea, para que una cuenta cortada por `dart format` también se vea).
List<String> cuentasDePlata(String codigo) {
  final sinComentarios = codigo
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
      .replaceAll(RegExp(r'//[^\n]*'), ' ');
  final plano = sinComentarios.replaceAll(RegExp(r'\s+'), ' ');
  return [
    for (final e in _cuentas.entries)
      for (final m in e.value.allMatches(plano)) '${e.key}: «${m.group(0)}»',
  ];
}

void main() {
  group('el detector', () {
    const cuentas = [
      'final pct = (1 - line.unitPrice / list) * 100;',
      'final rest = total - items - zoneSurcharge - expressSurchargeInTotal;',
      'final s = item.quantity * item.cylinder.price;',
      'final s = qty * cylinder.price;',
      'final u = cylinder.price * (100 - d.percentage) / 100;',
      'final u = d.unitPrice! * qty;',
      'final f = d.percentage * 0.01;',
      'final t = lines.fold(0.0, (a, l) => a + l.subtotal);',
      'final u = cylinder.price *\n      (1 - d.percentage / 100);',
      'money.format(cylinder.price * (1 - d.percentage / 100))',
    ];
    for (final c in cuentas) {
      test('marca: $c', () => expect(cuentasDePlata(c), isNotEmpty));
    }

    const mostrar = [
      "Text(money.format(o.total))",
      "value: money.format(i.subtotal!)",
      "'−\${d.percentage.toStringAsFixed(0)}% x\${d.quantity}'",
      'final total = _num(raw["total_amount"]);',
      'paymentSurchargeAmount ?? 0',
      '// final x = price * 2;',
      'final pages = (count / 20).ceil();',
      'width: size.width * 0.8,',
    ];
    for (final c in mostrar) {
      test('no marca: $c', () => expect(cuentasDePlata(c), isEmpty));
    }
  });

  test('lib/ no calcula precios, subtotales, recargos ni descuentos', () {
    final hallazgos = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))) {
      for (final c in cuentasDePlata(f.readAsStringSync())) {
        hallazgos.add('${f.path}: $c');
      }
    }
    expect(hallazgos, isEmpty, reason: hallazgos.join('\n'));
  });
}
