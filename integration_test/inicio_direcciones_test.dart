import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splg_customer/main.dart' as app;

import 'flujo_basico_test.dart'
    show
        pumpUntil,
        shot,
        tapF,
        tapText,
        tapKey,
        type,
        menuTo,
        login,
        back,
        homeField,
        openCatalog;

/// Dirección elegida en el Inicio (alta, cancelar, borrar) y pedido recién
/// creado. Usa cliente@splg.com: crea una dirección de prueba y la borra, y
/// crea y cancela un pedido.
///
///   flutter test integration_test/inicio_direcciones_test.dart -d `simulador` \
///     --dart-define=API_BASE_URL=http://localhost:3010 \
///     --dart-define=DISTRIBUTOR=demo --dart-define=PUSH_ENABLED=false
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente: Inicio, dirección elegida y pedido nuevo', (t) async {
    await app.main();
    final start = find.byWidgetPredicate((w) =>
        w is Text && (w.data == 'Comenzar' || w.data == '¿Qué necesitás?'));
    await pumpUntil(t, start, seconds: 40);
    if (find.text('Comenzar').evaluate().isNotEmpty) {
      await tapText(t, 'Comenzar');
      await pumpUntil(t, find.text('¡Hola!'));
      await login(t, 'cliente@splg.com', 'Test1234');
    }
    await pumpUntil(t, find.textContaining('Entregar en:'));
    final before =
        (find.textContaining('Entregar en:').evaluate().single.widget as Text)
            .data!;
    await shot(t, 'rev2-00-inicio');

    // B: el alta elige la dirección creada (no la predeterminada).
    await tapF(t, find.byTooltip('Agregar dirección'));
    await type(t, find.byKey(const Key('addr-street')), 'Sarmiento');
    await type(t, find.byKey(const Key('addr-number')), '1700');
    await type(t, find.byKey(const Key('addr-city')), 'Posadas');
    await tapText(t, 'Guardar');
    await pumpUntil(t, find.text('Entregar en: Sarmiento 1700'), seconds: 40);
    await shot(t, 'rev2-B1-alta-elige-la-nueva');

    // B: cancelar el formulario no cambia nada.
    await tapF(t, find.byTooltip('Agregar dirección'));
    await pumpUntil(t, find.byKey(const Key('addr-street')));
    await back(t);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Entregar en: Sarmiento 1700'), findsOneWidget);
    await shot(t, 'rev2-B2-cancelar-no-cambia');

    // E: pedido con la dirección nueva; el seguimiento abre el recién creado.
    await openCatalog(t);
    await tapF(t, find.byTooltip('Agregar uno').first);
    await tapF(t, find.textContaining('Continuar ·').last);
    await pumpUntil(t, find.text('Confirmación'));
    await tapKey(t, 'checkout-date');
    final ok = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').toUpperCase() == 'ACEPTAR');
    await pumpUntil(t, ok);
    final target = DateTime.now().add(const Duration(days: 2));
    await tapF(
        t,
        find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text('${target.day}')));
    await tapF(t, ok);
    await t.pump(const Duration(seconds: 2));
    final slot = find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${w.key}'.contains('slot-'));
    await pumpUntil(t, slot);
    await t.tap(slot.first);
    await t.pump(const Duration(seconds: 1));
    await shot(t, 'rev2-E1-confirmacion');
    await tapText(t, 'Confirmar pedido');
    await pumpUntil(t, find.byIcon(Icons.arrow_back), seconds: 40);
    await t.pump(const Duration(seconds: 4));
    await shot(t, 'rev2-E2-seguimiento-del-nuevo');
    await tapF(t, find.byIcon(Icons.arrow_back).first);

    // El pedido nuevo es el primero de Mis pedidos y el del seguimiento.
    await menuTo(t, 'Mis pedidos');
    await pumpUntil(t, find.textContaining('PENDIENTE'), seconds: 40);
    await shot(t, 'rev2-E3-mis-pedidos');
    await tapF(t, find.textContaining('PENDIENTE'));
    await pumpUntil(t, find.text('Cancelar pedido'));
    await tapText(t, 'Cancelar pedido');
    await pumpUntil(t, find.text('¿Por qué querés cancelar?'));
    await tapText(t, 'Pedí por error');
    await tapText(t, 'Confirmar cancelación');
    await pumpUntil(t, find.text('Pedido cancelado'), seconds: 40);
    await tapText(t, 'Volver');
    await back(t);
    await back(t);
    await pumpUntil(t, homeField);

    // C: se borra la dirección elegida desde Mis direcciones; el Inicio vuelve
    // a la anterior y avisa.
    await menuTo(t, 'Mis direcciones');
    await pumpUntil(t, find.text('Sarmiento 1700'));
    final row = find.ancestor(
        of: find.text('Sarmiento 1700'), matching: find.byType(Container));
    await t.tap(find
        .descendant(of: row.first, matching: find.byTooltip('Opciones'))
        .first);
    await t.pump(const Duration(seconds: 1));
    await tapText(t, 'Eliminar');
    await pumpUntil(t, find.text('Eliminar dirección'));
    await tapText(t, 'Eliminar');
    await t.pump(const Duration(seconds: 3));
    await back(t);
    await pumpUntil(t, find.byKey(const Key('home-address-notice')));
    expect(find.text('Entregar en: Sarmiento 1700'), findsNothing);
    expect(find.text(before), findsOneWidget);
    await shot(t, 'rev2-C1-borrada-vuelve-con-aviso');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
