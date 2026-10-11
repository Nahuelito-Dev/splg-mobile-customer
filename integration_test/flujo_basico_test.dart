import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:splg_customer/main.dart' as app;

/// Recorrido de la app cliente contra el back real (menú lateral, pedidos,
/// direcciones, reclamos, perfil, cierre de sesión y baja de una cuenta de
/// prueba).
///
///   flutter test integration_test/flujo_basico_test.dart -d `simulador` \
///     --dart-define=API_BASE_URL=http://localhost:3010 \
///     --dart-define=DISTRIBUTOR=demo \
///     --dart-define=PUSH_ENABLED=false
///
/// `PUSH_ENABLED=false` es necesario en simulador: sin eso el prompt de
/// notificaciones del sistema tapa la pantalla y el test no puede avanzar.
///
/// Efectos sobre la base (usalo sólo contra una de desarrollo):
///  - usa la cuenta cliente@splg.com / Test1234: crea, edita y borra una
///    dirección de prueba y crea y cancela un pedido;
///  - registra una cuenta nueva `qa.<timestamp>@splg.com` y la da de baja.
///    La cuenta cliente@splg.com NO se elimina.
final homeField = find.byKey(const Key('home-catalog-field'));

Future<void> openCatalog(WidgetTester t) async {
  await tapF(t, homeField);
  await pumpUntil(t, find.text('Garrafa 10kg'));
}

Future<void> closeCatalog(WidgetTester t) async {
  await t.tapAt(const Offset(200, 40));
  await t.pump(const Duration(seconds: 1));
  await pumpUntil(t, homeField);
}

Future<void> pumpUntil(WidgetTester t, Finder f, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció: $f');
}

Finder byHint(String hint) => find
    .byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint)
    .last;

Future<void> shot(WidgetTester t, String name) async {
  // Un watcher externo toma la captura cuando ve esta marca.
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
  // ignore: avoid_print
  print('SHOT:$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
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

Future<void> login(WidgetTester t, String email, String pass) async {
  await type(t, byHint('Email'), email);
  await type(t, byHint('Contraseña'), pass);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await tapText(t, 'Continuar');
  await pumpUntil(t, homeField, seconds: 40);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente: recorrido completo', (t) async {
    await app.main();

    // ── Acceso ──
    final start = find.byWidgetPredicate((w) =>
        w is Text && (w.data == 'Comenzar' || w.data == '¿Qué necesitás?'));
    await pumpUntil(t, start, seconds: 40);
    if (homeField.evaluate().isNotEmpty) {
      // Quedó una sesión de una corrida anterior: se cierra.
      await openMenu(t);
      await tapText(t, 'Cerrar sesión');
      await pumpUntil(t, find.text('¿Querés cerrar sesión?'));
      await t.tap(find.text('Cerrar sesión').last);
      await pumpUntil(t, find.text('¡Hola!'));
    } else {
      await shot(t, '01-bienvenida');
      await tapText(t, 'Comenzar');
      await pumpUntil(t, find.text('¡Hola!'));
    }
    await shot(t, '02-login');

    // Recuperar contraseña (sin mandar el mail real).
    await tapText(t, '¿Olvidaste tu contraseña?');
    await pumpUntil(t, find.text('RECUPERAR CONTRASEÑA'));
    await shot(t, '03-recuperar');
    await back(t);

    // Login con error y con éxito.
    await type(t, byHint('Email'), 'cliente@splg.com');
    await type(t, byHint('Contraseña'), 'mala-clave');
    await tapText(t, 'Continuar');
    await pumpUntil(t, find.textContaining('No pudimos iniciar sesión'));
    await shot(t, '04-login-error');
    await login(t, 'cliente@splg.com', 'Test1234');

    // ── Inicio ──
    await pumpUntil(t, homeField);
    await shot(t, '05-inicio');
    await openCatalog(t);
    await shot(t, '05b-inicio-catalogo');
    await closeCatalog(t);
    await openMenu(t);
    await pumpUntil(t, find.text('Menú'));
    await shot(t, '06-menu');
    await t.tap(find.byTooltip('Cerrar menú'));
    await t.pump(const Duration(seconds: 1));

    // ── Mi perfil ──
    await menuTo(t, 'Mi perfil');
    await pumpUntil(t, find.text('Información personal'));
    await shot(t, '07-perfil');
    await tapText(t, 'Información personal');
    await shot(t, '08-info-personal');
    await back(t);
    await tapText(t, 'Editar perfil');
    await shot(t, '09-editar-perfil');
    await back(t);
    await tapText(t, 'Cambiar contraseña');
    await shot(t, '10-cambiar-contrasena');
    await back(t);
    await back(t);

    // ── Mis direcciones: alta, edición, predeterminada y baja ──
    await menuTo(t, 'Mis direcciones');
    await pumpUntil(t, find.byKey(const Key('address-new')));
    await shot(t, '11-direcciones');
    await tapKey(t, 'address-new');
    await type(t, find.byKey(const Key('addr-street')), 'Rivadavia');
    await type(t, find.byKey(const Key('addr-number')), '1500');
    await type(t, find.byKey(const Key('addr-city')), 'Posadas');
    await type(
        t, find.byKey(const Key('addr-reference')), 'Dirección de prueba');
    await shot(t, '12-direccion-nueva');
    await tapText(t, 'Guardar');
    await pumpUntil(t, find.text('Rivadavia 1500'), seconds: 40);
    await shot(t, '13-direccion-creada');

    // Editar la referencia.
    final tile = find.ancestor(
        of: find.text('Rivadavia 1500'), matching: find.byType(Container));
    await t.tap(find
        .descendant(of: tile.first, matching: find.byTooltip('Opciones'))
        .first);
    await t.pump(const Duration(seconds: 1));
    await tapText(t, 'Editar');
    await pumpUntil(t, find.text('Editar dirección'));
    await type(t, find.byKey(const Key('addr-reference')), 'Prueba editada');
    await shot(t, '14-direccion-editar');
    await tapText(t, 'Guardar');
    await pumpUntil(t, find.textContaining('Prueba editada'), seconds: 40);

    // Predeterminada y de vuelta.
    Future<void> rowMenu(String street, String option) async {
      final row = find.ancestor(
          of: find.text(street), matching: find.byType(Container));
      await t.tap(find
          .descendant(of: row.first, matching: find.byTooltip('Opciones'))
          .first);
      await t.pump(const Duration(seconds: 1));
      await tapText(t, option);
    }

    await rowMenu('Rivadavia 1500', 'Marcar como predeterminada');
    await pumpUntil(t, find.text('Predeterminada'));
    await shot(t, '15-direccion-predeterminada');
    await rowMenu('Buenos Aires 4114', 'Marcar como predeterminada');
    await t.pump(const Duration(seconds: 2));
    // Baja de la dirección de prueba.
    await rowMenu('Rivadavia 1500', 'Eliminar');
    await pumpUntil(t, find.text('Eliminar dirección'));
    await shot(t, '16-direccion-eliminar');
    await tapText(t, 'Eliminar');
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Rivadavia 1500'), findsNothing);
    await shot(t, '17-direccion-eliminada');
    await back(t);

    // ── Pedido: catálogo, confirmación y cancelación ──
    await openCatalog(t);
    final add = find.byTooltip('Agregar uno').first;
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, '18-inicio-con-carrito');
    await tapF(t, find.textContaining('Continuar ·').last);
    await pumpUntil(t, find.text('Confirmación'));
    await shot(t, '19-confirmacion');
    // El back compara la fecha en UTC: de noche (hora argentina) "hoy" ya es
    // una fecha pasada para él, así que se agenda para dentro de dos días.
    await tapKey(t, 'checkout-date');
    final ok = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').toUpperCase() == 'ACEPTAR');
    await pumpUntil(t, ok);
    final target = DateTime.now().add(const Duration(days: 2));
    await shot(t, '19b-calendario');
    await tapF(
        t,
        find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text('${target.day}')));
    await tapF(t, ok);
    await t.pump(const Duration(seconds: 2));
    // Si faltaba la franja, el botón estaba apagado: se elige una.
    final slot = find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${w.key}'.contains('slot-'));
    await pumpUntil(t, slot);
    await t.tap(slot.first);
    await t.pump(const Duration(seconds: 1));
    await shot(t, '20-confirmacion-franja');
    await tapText(t, 'Confirmar pedido');
    // El seguimiento (con el mapa) es de la tanda 3: conserva su flecha.
    await pumpUntil(t, find.byIcon(Icons.arrow_back), seconds: 40);
    await t.pump(const Duration(seconds: 4));
    await shot(t, '21-seguimiento');
    await tapF(t, find.byIcon(Icons.arrow_back).first);

    await menuTo(t, 'Mis pedidos');
    await pumpUntil(t, find.textContaining('PENDIENTE'), seconds: 40);
    await shot(t, '22-mis-pedidos');
    await tapF(t, find.textContaining('PENDIENTE'));
    await pumpUntil(t, find.text('Cancelar pedido'));
    await shot(t, '23-detalle-pedido');
    await tapText(t, 'Cancelar pedido');
    await pumpUntil(t, find.text('¿Por qué querés cancelar?'));
    await tapText(t, 'Pedí por error');
    await shot(t, '24-cancelar-motivo');
    await tapText(t, 'Confirmar cancelación');
    await pumpUntil(t, find.text('Pedido cancelado'), seconds: 40);
    await shot(t, '25-pedido-cancelado');
    await tapText(t, 'Volver');
    await pumpUntil(t, find.textContaining('CANCELADO'));
    await shot(t, '26-detalle-cancelado');
    await back(t);
    await pumpUntil(t, find.textContaining('CANCELADO'));
    await shot(t, '26b-mis-pedidos-cancelado');
    await back(t);

    // ── Mis reclamos, notificaciones y contenido ──
    await menuTo(t, 'Mis reclamos');
    await pumpUntil(t, find.text('Mis reclamos'));
    await t.pump(const Duration(seconds: 3));
    await shot(t, '27-mis-reclamos');
    await back(t);
    await menuTo(t, 'Notificaciones');
    await pumpUntil(t, find.text('¡Nada por aquí!'));
    await shot(t, '28-notificaciones');
    await back(t);
    await menuTo(t, 'Ayuda');
    await pumpUntil(t, find.text('¿Cómo hago un pedido?'));
    await shot(t, '29-ayuda');
    await back(t);
    await menuTo(t, 'Términos y condiciones');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '30-terminos');
    await back(t);
    await menuTo(t, 'Políticas de privacidad');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '31-privacidad');
    await back(t);
    await menuTo(t, 'Acerca de SPLG');
    await shot(t, '32-acerca-de');
    await back(t);

    // ── Cerrar sesión ──
    await openMenu(t);
    await pumpUntil(t, find.text('Menú'));
    await tapText(t, 'Cerrar sesión');
    await pumpUntil(t, find.text('¿Querés cerrar sesión?'));
    await shot(t, '33-cerrar-sesion');
    await t.tap(find.text('Cerrar sesión').last);
    await pumpUntil(t, find.text('¡Hola!'));
    await shot(t, '34-login-tras-cerrar');

    // ── Registro de una cuenta de prueba y su baja ──
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'qa.$stamp@splg.com';
    await tapText(t, 'Registrarse');
    await pumpUntil(t, find.text('1. Tus datos'));
    await tapText(t, 'Siguiente');
    await shot(t, '35-registro-paso1-error');
    await type(t, find.byKey(const Key('signup-name')), 'QA Tanda Dos');
    await type(t, find.byKey(const Key('signup-phone')),
        '38155${(stamp % 100000).toString().padLeft(5, '0')}');
    await shot(t, '36-registro-paso1');
    await tapText(t, 'Siguiente');
    await pumpUntil(t, find.text('2. Tu cuenta'));
    await type(t, find.byKey(const Key('signup-email')), email);
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
    await tapText(t, 'Registrarme');
    await pumpUntil(t, find.textContaining('aceptá'));
    await shot(t, '37-registro-paso2-error');
    await tapF(t, find.byIcon(SplgIcons.checkOff).first);
    await tapF(t, find.byIcon(SplgIcons.checkOff).first);
    await shot(t, '38-registro-paso2');
    await tapText(t, 'Registrarme');
    await pumpUntil(t, find.text('¡Registro completado!'), seconds: 60);
    await shot(t, '39-registro-completado');
    await tapText(t, 'Ir al inicio');
    await pumpUntil(t, homeField, seconds: 40);

    // Baja de la cuenta de prueba (definitiva, el email queda reservado).
    await menuTo(t, 'Mi perfil');
    await pumpUntil(t, find.text('Eliminar cuenta'));
    await tapText(t, 'Eliminar cuenta');
    await pumpUntil(t, find.text('¿Eliminar tu cuenta?'));
    await shot(t, '40-eliminar-cuenta');
    await t.tap(find.text('Eliminar cuenta').last);
    await pumpUntil(t, find.text('Comenzar'), seconds: 40);
    await shot(t, '41-cuenta-eliminada');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
