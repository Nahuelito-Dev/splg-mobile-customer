import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/main.dart' as app;

import 'flujo_basico_test.dart'
    show pumpUntil, shot, tapText, menuTo, login, back, homeField, openMenu;

/// Mis pedidos con más de una página, el polling del inicio de fondo y los
/// errores de red (se simulan apuntando el cliente HTTP a un puerto cerrado).
///
///   flutter test integration_test/pedidos_y_red_test.dart -d `simulador` \
///     --dart-define=API_BASE_URL=http://localhost:3010 \
///     --dart-define=DISTRIBUTOR=demo --dart-define=PUSH_ENABLED=false
///
/// Usa la cuenta cliente@splg.com / Test1234, sólo en lectura.
final orderCards = find.byWidgetPredicate(
    (w) => w.key is ValueKey && '${w.key}'.contains('[<\'order-'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente: pedidos paginados y red caída', (t) async {
    await app.main();
    final start = find.byWidgetPredicate((w) =>
        w is Text && (w.data == 'Comenzar' || w.data == '¿Qué necesitás?'));
    await pumpUntil(t, start, seconds: 40);
    if (find.text('Comenzar').evaluate().isNotEmpty) {
      await tapText(t, 'Comenzar');
      await pumpUntil(t, find.text('¡Hola!'));
      await login(t, 'cliente@splg.com', 'Test1234');
    }

    // ── Mis pedidos: bajar hasta el final de las páginas ──
    await menuTo(t, 'Mis pedidos');
    await pumpUntil(t, orderCards);
    await shot(t, 'pedidos-01-primera-pagina');
    final keys = <String>{};
    void collect() =>
        keys.addAll(orderCards.evaluate().map((e) => '${e.widget.key}'));
    collect();
    var idle = 0;
    for (var i = 0; i < 60 && idle < 3; i++) {
      final before = keys.length;
      await t.drag(find.byType(ListView).last, const Offset(0, -300));
      await t.pump(const Duration(milliseconds: 600));
      collect();
      idle = keys.length == before ? idle + 1 : 0;
    }
    final seen = keys.length;
    // ignore: avoid_print
    print('PEDIDOS-VISTOS:$seen');
    expect(seen, greaterThan(20), reason: 'la lista pasó de la primera página');
    await shot(t, 'pedidos-02-mas-de-20');

    // Más de 10 s con el polling del inicio de fondo: la lista no se achica.
    await t.pump(const Duration(seconds: 12));
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 12)));
    await t.pump(const Duration(seconds: 1));
    expect(orderCards.evaluate(), isNotEmpty);
    await shot(t, 'pedidos-03-despues-de-12s');

    // ── Red caída ──
    final dio = ApiClient.instance.dio;
    final base = dio.options.baseUrl;
    dio.options.baseUrl = 'http://localhost:3999';
    await t.fling(find.byType(ListView).last, const Offset(0, 600), 1000);
    await t.pump(const Duration(seconds: 4));
    expect(orderCards.evaluate(), isNotEmpty,
        reason: 'un refresco fallido no pisa la lista');
    await shot(t, 'pedidos-04-refresco-sin-red');
    await back(t);

    await menuTo(t, 'Mis direcciones');
    await pumpUntil(t, find.text('Reintentar'), seconds: 40);
    await shot(t, 'direcciones-sin-red');
    dio.options.baseUrl = base;
    await tapText(t, 'Reintentar');
    await pumpUntil(t, find.byKey(const Key('address-new')));
    await shot(t, 'direcciones-reintento-ok');
    await back(t);

    dio.options.baseUrl = 'http://localhost:3999';
    await menuTo(t, 'Mis pedidos');
    await pumpUntil(t, find.text('Reintentar'), seconds: 40);
    await shot(t, 'pedidos-05-sin-red');
    dio.options.baseUrl = base;
    await tapText(t, 'Reintentar');
    await pumpUntil(t, orderCards);
    await shot(t, 'pedidos-06-reintento-ok');
    await back(t);

    // ── Cerrar sesión y volver a entrar ──
    await openMenu(t);
    await tapText(t, 'Cerrar sesión');
    await pumpUntil(t, find.text('¿Querés cerrar sesión?'));
    await t.tap(find.text('Cerrar sesión').last);
    await pumpUntil(t, find.text('¡Hola!'));
    await shot(t, 'sesion-01-login-tras-cerrar');
    await login(t, 'cliente@splg.com', 'Test1234');
    await shot(t, 'sesion-02-login-otra-vez');
    expect(homeField, findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
