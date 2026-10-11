import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splg_customer/main.dart' as app;

/// Recorrido de la app cliente contra el back real.
///
///   flutter test integration_test/flujo_basico_test.dart -d `simulador` \
///     --dart-define=API_BASE_URL=http://localhost:3010 \
///     --dart-define=DISTRIBUTOR=`slug-vigente-en-la-base` \
///     --dart-define=PUSH_ENABLED=false
///
/// `PUSH_ENABLED=false` es necesario en simulador: sin eso el prompt de
/// notificaciones del sistema tapa la pantalla y el test no puede avanzar.
///
/// Efectos sobre la base (usalo sólo contra una de desarrollo):
///  - usa la cuenta cliente@splg.com / Test1234 (crea y cancela un pedido,
///    edita el nombre y lo deja como estaba al terminar);
///  - crea una cuenta nueva `qa.<timestamp>@splg.com` por corrida;
///  - Firebase manda un mail real de recuperación a cliente@splg.com.
Future<void> pumpUntil(
  WidgetTester t,
  Finder f, {
  int seconds = 30,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció: $f');
}

Finder byHint(String hint) => find
    .byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    )
    .last;

Future<void> shot(WidgetTester t, String name) async {
  // Un watcher externo toma la captura cuando ve esta marca.
  // ignore: avoid_print
  print('SHOT:$name');
  await t.pump(const Duration(seconds: 3));
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await pumpUntil(t, f);
  await t.ensureVisible(f.first);
  await t.tap(f.first);
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente: catálogo, pedido, historial y perfil', (t) async {
    await app.main();

    // Catálogo con precio y promociones por cantidad.
    await pumpUntil(t, find.text('Garrafa 10kg'));
    expect(find.text(r'$14.900'), findsOneWidget);
    expect(find.textContaining('a partir de'), findsWidgets);
    await shot(t, '02-catalogo');

    // Dos garrafas de 10kg: aparece el total y el botón Pedir.
    final add = find.byIcon(Icons.add_circle_outline).first;
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('2'), findsWidgets);
    await tapText(t, 'Pedir');

    // Si no hay sesión, el flujo pasa por el login.
    final continuar = find.text('Continuar');
    await t.pump(const Duration(seconds: 2));
    if (continuar.evaluate().isNotEmpty) {
      await shot(t, '01-login');
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), 'cliente@splg.com');
      await t.enterText(fields.at(1), 'Test1234');
      await t.tap(continuar);
      await pumpUntil(t, find.text('Garrafa 10kg'));
      await tapText(t, 'Pedir');
    }

    // Checkout: franja, dirección, pago efectivo y confirmación.
    await pumpUntil(t, find.text('CONFIRMAR PEDIDO'));
    await shot(t, '03-checkout');
    expect(find.text('Efectivo'), findsWidgets);

    final chips = find.byType(ChoiceChip);
    await pumpUntil(t, chips);
    await t.ensureVisible(chips.first);
    await t.tap(chips.first);
    await t.pump(const Duration(milliseconds: 500));
    await t.ensureVisible(find.text('CONFIRMAR PEDIDO'));
    await t.tap(find.text('CONFIRMAR PEDIDO'));

    // Seguimiento del pedido recién creado: pendiente y cancelable.
    await pumpUntil(t, find.text('Cancelar pedido'), seconds: 40);
    await shot(t, '04-detalle-pedido');
    await t.ensureVisible(find.text('Cancelar pedido'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('Cancelar pedido'));
    await t.pump(const Duration(seconds: 1));

    // Cancelar el pedido pendiente: vuelve al inicio y queda CANCELADO.
    await pumpUntil(t, find.byIcon(Icons.history), seconds: 20);
    await t.tap(find.byIcon(Icons.history));
    await pumpUntil(t, find.text('CANCELADO'));
    await shot(t, '05-historial-cancelado');

    // Perfil: ver y editar el nombre.
    await t.tap(find.byIcon(BootstrapIcons.person_gear));
    await tapText(t, 'Perfil');
    await pumpUntil(t, find.text('Mi Perfil'));
    expect(find.text('cliente@splg.com'), findsWidgets);
    await shot(t, '06-perfil');
    final original =
        t.widget<Text>(find.textContaining('Cliente Prueba').first).data!;
    final nombre =
        '$original ${String.fromCharCode(65 + DateTime.now().second % 26)}';
    await t.tap(find.byIcon(Icons.edit_outlined).first);
    await pumpUntil(t, find.text('Editar nombre'));
    await t.enterText(find.byType(TextField).last, nombre);
    await tapText(t, 'Guardar');
    await pumpUntil(t, find.text('Datos actualizados.'));
    expect(find.text(nombre), findsWidgets);

    // La cuenta demo queda con su nombre original.
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byIcon(Icons.edit_outlined).first);
    await pumpUntil(t, find.text('Editar nombre'));
    await t.enterText(find.byType(TextField).last, original);
    await tapText(t, 'Guardar');
    await pumpUntil(t, find.text(original));

    // Direcciones: el listado se muestra con la predeterminada marcada.
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byIcon(Icons.edit_outlined).last);
    await pumpUntil(t, find.text('Agregar'));
    await shot(t, '07-direcciones');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pump(const Duration(seconds: 1));

    // Cerrar sesión.
    await t.pump(const Duration(seconds: 2));
    await t.ensureVisible(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await t.pump(const Duration(seconds: 1));
    expect(
        find.text('¿Estás seguro que deseas cerrar sesión?'), findsOneWidget);
    await t.tap(find.text('Cerrar sesión').last);
    await t.pump(const Duration(seconds: 2));
    await pumpUntil(t, find.text('Garrafa 10kg'));

    // Recuperar contraseña desde el login.
    await t.tap(find.byIcon(Icons.add_circle_outline).first);
    await t.pump(const Duration(milliseconds: 300));
    await tapText(t, 'Pedir');
    await pumpUntil(t, find.text('¿Olvidaste tu contraseña?'));
    await shot(t, '01-login');
    await t.tap(find.text('¿Olvidaste tu contraseña?'));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Ingresá tu email'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).at(0), 'cliente@splg.com');
    await t.tap(find.text('¿Olvidaste tu contraseña?'));
    await pumpUntil(t, find.text('Revisá tu correo'));
    await shot(t, '08-recuperar-contrasena');
    await tapText(t, 'Ok');

    // Credenciales mal: mensaje claro y se queda en el login.
    await t.enterText(find.byType(TextFormField).at(1), 'clave-mala');
    await t.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await pumpUntil(t, find.textContaining('No se pudo iniciar sesión'));
    await shot(t, '09-login-error');
    await tapText(t, 'Ok');
    expect(find.text('Continuar'), findsOneWidget);

    // Registro: con un email que ya existe falla con aviso.
    final irARegistro = find.textContaining('Registrarse', findRichText: true);
    await pumpUntil(t, irARegistro);
    await t.tap(irARegistro.last);
    await pumpUntil(t, find.widgetWithText(ElevatedButton, 'Registrarse'));
    final sufijo = '${DateTime.now().millisecondsSinceEpoch}'.substring(8);
    Future<void> completar(String email, String telefono) async {
      await t.enterText(byHint('Nombre y apellido'), 'QA Cliente');
      await t.enterText(byHint('Email'), email);
      await t.enterText(byHint('Contraseña'), 'Test1234');
      await t.enterText(byHint('Número de teléfono'), telefono);
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.widgetWithText(ElevatedButton, 'Registrarse'));
      await t.tap(find.widgetWithText(ElevatedButton, 'Registrarse'));
    }

    // Mismo email, teléfono nuevo.
    await completar('cliente@splg.com', '38155$sufijo');
    await pumpUntil(t, find.textContaining('Ya existe una cuenta'));
    await shot(t, '10-registro-error');
    await tapText(t, 'Ok');

    // Registro válido: queda con la sesión iniciada en el inicio.
    final email = 'qa.${DateTime.now().millisecondsSinceEpoch}@splg.com';
    await completar(email, '38155$sufijo');
    await pumpUntil(t, find.text('Garrafa 10kg'), seconds: 40);
    await shot(t, '11-registro-ok');

    // Navegación: cuenta -> perfil -> legales, y volver.
    await t.tap(find.byIcon(BootstrapIcons.person_gear));
    await pumpUntil(t, find.text('Configuraciones'));
    await shot(t, '12a-cuenta');
    await tapText(t, 'Privacidad');
    await pumpUntil(t, find.textContaining('Política de Privacidad'));
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pump(const Duration(seconds: 2));
    await tapText(t, 'Perfil');
    await pumpUntil(t, find.text('Mi Perfil'));
    expect(find.text('QA Cliente'), findsWidgets);
    await tapText(t, 'Términos y Condiciones');
    await pumpUntil(t, find.textContaining('Bienvenido'));
    await shot(t, '12-terminos');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pump(const Duration(seconds: 2));
    await tapText(t, 'Política de Privacidad');
    await pumpUntil(t, find.textContaining('SPLG'));
    await shot(t, '13-privacidad');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pump(const Duration(seconds: 2));
    await t.ensureVisible(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Cerrar sesión').last);
    await pumpUntil(t, find.text('Garrafa 10kg'));
  });
}
