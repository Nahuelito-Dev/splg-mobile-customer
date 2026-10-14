import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'package:splg_lib/splg_lib.dart';

class _Model extends LoadViewModel {
  _Model(this.failure);

  final Object failure;
  var fetches = 0;

  @override
  Future<void> fetch() async {
    fetches++;
    throw failure;
  }
}

Future<void> _open(WidgetTester t, _Model model) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await model.load();
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: LoadScaffold(
      title: 'Pedido',
      model: model,
      bell: false,
      builder: (_) => const SizedBox(),
    ),
  ));
}

void main() {
  testWidgets('un recurso que ya no existe ofrece Volver, no Reintentar',
      (t) async {
    final model = _Model(const LoadFailure('Ya no está', retryable: false));
    await _open(t, model);

    expect(find.text('Ya no está'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.byKey(const Key('load-back')), findsOneWidget);
    expect(model.canRetry, isFalse);
  });

  testWidgets('una falla común sigue ofreciendo Reintentar', (t) async {
    final model = _Model(const LoadFailure('Sin conexión'));
    await _open(t, model);

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byKey(const Key('load-back')), findsNothing);
  });
}
