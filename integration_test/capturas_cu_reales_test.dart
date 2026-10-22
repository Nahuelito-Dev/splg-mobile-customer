import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:splg_customer/main.dart' as app;

/// Capturas de las pantallas reales de los CU Reales de la app cliente
/// (`3-Diseño.md` §3 de `splg-docs`). Cada `SHOT:<nombre>` es una captura que
/// saca `scripts/capturas_cu_reales.py`; `READY:en-camino` le pide que prepare
/// por la API el pedido en camino.
///
///   scripts/capturas_cu_reales.py
///
/// o, sin capturas ni preparación de datos:
///
///   flutter test integration_test/capturas_cu_reales_test.dart -d `simulador` \
///     --dart-define=API_BASE_URL=http://localhost:3010 \
///     --dart-define=PUSH_ENABLED=false
///
/// Efectos (usalo sólo contra una base de desarrollo): con cliente@splg.com crea
/// un pedido «Prueba capturas» desde la app y lo cancela; el registro (CU-002) y
/// el reclamo (CU-023) se completan sin enviar.
final homeField = find.byKey(const Key('home-catalog-field'));

Future<void> pumpUntil(WidgetTester t, Finder f, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toList();
  // ignore: avoid_print
  print('PANTALLA: $texts');
  // ignore: avoid_print
  print('SHOT:fallo');
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  throw TestFailure('No apareció: $f');
}

Finder byHint(String hint) => find
    .byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint)
    .last;

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
  // ignore: avoid_print
  print('SHOT:$name');
  // El script externo saca la captura mientras el test espera.
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> tapF(WidgetTester t, Finder f) async {
  await pumpUntil(t, f);
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 200));
  await t.tap(f.first);
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> tapText(WidgetTester t, String text) => tapF(t, find.text(text));
Future<void> tapKey(WidgetTester t, String key) =>
    tapF(t, find.byKey(Key(key)));
Future<void> back(WidgetTester t) => tapF(t, find.byTooltip('Volver'));

Future<void> type(WidgetTester t, Finder f, String text) async {
  await pumpUntil(t, f);
  await t.ensureVisible(f.first);
  await t.enterText(f.first, text);
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> openMenu(WidgetTester t) => tapF(t, find.byTooltip('Abrir menú'));

Future<void> menuTo(WidgetTester t, String item) async {
  await openMenu(t);
  await pumpUntil(t, find.text('Menú'));
  await tapText(t, item);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente: capturas de los CU Reales', (t) async {
    await app.main();

    // ── Acceso: si quedó una sesión de una corrida anterior, se cierra ──
    final start = find.byWidgetPredicate((w) =>
        w is Text && (w.data == 'Comenzar' || w.data == '¿Qué necesitás?'));
    await pumpUntil(t, start, seconds: 40);
    if (homeField.evaluate().isNotEmpty) {
      await openMenu(t);
      await tapText(t, 'Cerrar sesión');
      await pumpUntil(t, find.text('¿Querés cerrar sesión?'));
      await t.tap(find.text('Cerrar sesión').last);
      await pumpUntil(t, find.text('¡Hola!'));
    } else {
      await tapText(t, 'Comenzar');
      await pumpUntil(t, find.text('¡Hola!'));
    }

    // ── CU-001: formulario de inicio de sesión completo, sin enviar ──
    await type(t, byHint('Email'), 'cliente@splg.com');
    await type(t, byHint('Contraseña'), 'Test1234');
    await shot(t, 'CU-001-iniciar-sesion');

    // ── CU-002: registro, paso 2 completo, sin enviar ──
    await tapText(t, 'Registrarse');
    await pumpUntil(t, find.text('1. Tus datos'));
    await type(t, find.byKey(const Key('signup-name')), 'María Gómez');
    await type(t, find.byKey(const Key('signup-phone')), '3815551234');
    await tapText(t, 'Siguiente');
    await pumpUntil(t, find.text('2. Tu cuenta'));
    await type(t, find.byKey(const Key('signup-email')), 'maria.gomez@gmail.com');
    await type(
        t,
        find.descendant(
            of: find.byKey(const Key('signup-password')),
            matching: find.byType(TextField)),
        'Test1234');
    await type(
        t,
        find.descendant(
            of: find.byKey(const Key('signup-repeat')),
            matching: find.byType(TextField)),
        'Test1234');
    await tapF(t, find.byIcon(SplgIcons.checkOff).first);
    await tapF(t, find.byIcon(SplgIcons.checkOff).first);
    await shot(t, 'CU-002-registro-cuenta');
    for (var i = 0; i < 4 && find.text('¡Hola!').evaluate().isEmpty; i++) {
      await back(t);
    }
    await pumpUntil(t, find.text('¡Hola!'));

    // Se entra con la cuenta de la demo.
    await type(t, byHint('Email'), 'cliente@splg.com');
    await type(t, byHint('Contraseña'), 'Test1234');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await tapText(t, 'Continuar');
    await pumpUntil(t, homeField, seconds: 40);

    // ── CU-041: catálogo con dos garrafas de 10 kg elegidas ──
    await tapF(t, homeField);
    await pumpUntil(t, find.text('Garrafa 10kg'));
    // Un carrito que quedó de una corrida anterior se vacía.
    await t.pump(const Duration(seconds: 2));
    if (find.textContaining('Continuar ·').evaluate().isNotEmpty) {
      await tapF(t, find.textContaining('Continuar ·').last);
      await pumpUntil(t, find.byKey(const Key('cart-clear')));
      await tapKey(t, 'cart-clear');
      await tapText(t, 'Vaciar');
      await pumpUntil(t, find.text('Tu carrito está vacío. Agregá garrafas desde el inicio.'));
      await back(t);
      await tapF(t, homeField);
      await pumpUntil(t, find.text('Garrafa 10kg'));
    }
    final add = find.byTooltip('Agregar uno').first;
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'CU-041-catalogo');

    // ── CU-005: confirmación del pedido con fecha y franja elegidas ──
    await tapF(t, find.textContaining('Continuar ·').last);
    await pumpUntil(t, find.byKey(const Key('cart-continue')));
    await tapKey(t, 'cart-continue');
    await pumpUntil(t, find.text('Confirmación'));
    // El back compara la fecha en UTC: de noche (hora argentina) "hoy" ya es
    // una fecha pasada para él, así que se agenda para dentro de dos días.
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
    // Se pliega la lista de franjas: queda a la vista el resumen con la elegida.
    await tapKey(t, 'checkout-slots');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 1500));
    await t.pump(const Duration(seconds: 1));
    await shot(t, 'CU-005-confirmacion-pedido');

    // ── CU-048: Mercado Pago elegido como forma de pago (sin pagar) ──
    await tapKey(t, 'checkout-payment');
    await tapKey(t, 'pay-mercadoPago');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 1500));
    await t.pump(const Duration(seconds: 1));
    await shot(t, 'CU-048-pago-mercadopago');

    // Se vuelve a efectivo y se confirma: nace el pedido de la prueba.
    await tapKey(t, 'checkout-payment');
    await tapKey(t, 'pay-cash');
    await tapText(t, 'Confirmar pedido');
    await pumpUntil(t, find.byKey(const Key('tracking-cancel')), seconds: 40);
    await t.pump(const Duration(seconds: 4));

    // ── CU-008: seguimiento con el botón «Cancelar pedido» ──
    await shot(t, 'CU-008-cancelar-pedido');
    await tapKey(t, 'tracking-cancel');
    await pumpUntil(t, find.text('¿Por qué querés cancelar?'));
    await tapText(t, 'Pedí por error');
    await shot(t, 'CU-008-cancelar-motivo');
    await tapText(t, 'Confirmar cancelación');
    await pumpUntil(t, find.text('Pedido cancelado'), seconds: 40);
    await tapText(t, 'Volver');
    await t.pump(const Duration(seconds: 2));
    for (var i = 0; i < 4 && homeField.evaluate().isEmpty; i++) {
      await back(t);
    }
    await pumpUntil(t, homeField, seconds: 40);

    // ── CU-023: hoja «Hacer un reclamo» de un pedido entregado, sin enviar ──
    await menuTo(t, 'Mis pedidos');
    await pumpUntil(t, find.textContaining('CANCELADO'), seconds: 40);
    // Los entregados están más abajo: se desplaza hasta que carguen.
    for (var i = 0;
        i < 8 && find.textContaining('ENTREGADO').evaluate().isEmpty;
        i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await t.pump(const Duration(seconds: 2));
    }
    await pumpUntil(t, find.textContaining('ENTREGADO'), seconds: 10);
    await tapF(t, find.textContaining('ENTREGADO'));
    await pumpUntil(t, find.text('Hacer un reclamo'));
    await tapText(t, 'Hacer un reclamo');
    await pumpUntil(t, find.text('Contanos qué pasó con este pedido y lo revisamos.'));
    await tapKey(t, 'claim-reason-Demora excesiva');
    await type(t, find.byType(TextField).last,
        'El pedido llegó dos horas después de la franja elegida.');
    await shot(t, 'CU-023-registrar-reclamo');
    await tapText(t, 'Cancelar');
    await t.pump(const Duration(seconds: 1));
    await back(t);
    await back(t);

    // ── Mis reclamos de la cuenta ──
    await menuTo(t, 'Mis reclamos');
    await pumpUntil(t, find.text('Mis reclamos'));
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'CU-023-mis-reclamos');
    await back(t);

    // ── CU-017 y CU-079: seguimiento con el chofer en camino ──
    // ignore: avoid_print
    print('READY:en-camino');
    // El script arma el pedido por la API; se le da tiempo antes de listar.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 15)));
    await menuTo(t, 'Mis pedidos');
    await pumpUntil(t, find.textContaining('EN CAMINO'), seconds: 90);
    await tapF(t, find.textContaining('EN CAMINO'));
    await tapText(t, 'Ver seguimiento');
    await pumpUntil(t, find.byKey(const Key('tracking-confirm-qr')),
        seconds: 40);
    await t.pump(const Duration(seconds: 8));
    await shot(t, 'CU-017-seguimiento-en-camino');
    await shot(t, 'CU-079-confirmar-entrega-qr');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
