import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/ui/common/formatters.dart';

void main() {
  test('un monto entero se muestra sin decimales', () {
    expect(money.format(1850), '\$1.850');
    expect(money.format(28310.0), '\$28.310');
  });

  test('un total con centavos (recargo del 10%) los muestra', () {
    expect(money.format(47701.5), '\$47.701,50');
    expect(money.format(2030.25), '\$2.030,25');
  });
}
