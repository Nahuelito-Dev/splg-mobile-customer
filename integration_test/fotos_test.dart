import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
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
        byHint,
        homeField,
        openCatalog,
        closeCatalog,
        openMenu;

/// Selector de fotos del sistema reemplazado por la plataforma de pruebas
/// (mecanismo oficial de image_picker): entrega una foto real del disco del
/// host. El resto del recorrido (reducción, subida multipart, URL firmada) es
/// el de la app.
class _FotoDelDisco extends ImagePickerPlatform {
  _FotoDelDisco(this.path);

  final String path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile.fromData(await File(path).readAsBytes(), name: 'foto.jpg');
}

/// Foto de perfil (agregar, ver en perfil y menú, quitar), reclamo con foto
/// sobre un pedido entregado y catálogo con fotos de S3. Usa cliente@splg.com.
///
///   FOTO=/ruta/foto.jpg flutter test integration_test/fotos_test.dart -d `simulador` \
///     --dart-define=API_BASE_URL=http://localhost:3010 \
///     --dart-define=DISTRIBUTOR=demo --dart-define=PUSH_ENABLED=false \
///     --dart-define=FOTO=/ruta/foto.jpg
///
/// Efectos en la base: sube y cambia la foto de un reclamo existente (no crea
/// reclamos salvo con `--dart-define=CREAR_RECLAMO=true`, y esos no se pueden
/// borrar). OTRA_CUENTA es el email de un segundo cliente (clave Test1234).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const foto = String.fromEnvironment('FOTO');
  const crearReclamo = bool.fromEnvironment('CREAR_RECLAMO');
  const otraCuenta = String.fromEnvironment('OTRA_CUENTA');

  testWidgets('cliente: fotos', (t) async {
    ImagePickerPlatform.instance = _FotoDelDisco(foto);
    await app.main();

    final start = find.byWidgetPredicate((w) =>
        w is Text && (w.data == 'Comenzar' || w.data == '¿Qué necesitás?'));
    await pumpUntil(t, start, seconds: 40);
    if (homeField.evaluate().isEmpty) {
      await tapText(t, 'Comenzar');
      await pumpUntil(t, find.text('¡Hola!'));
      await login(t, 'cliente@splg.com', 'Test1234');
    }

    // Catálogo con fotos de S3.
    await openCatalog(t);
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'catalogo-con-fotos');
    await tapText(t, 'Garrafa 10kg');
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'catalogo-detalle');
    await t.tapAt(const Offset(200, 40));
    await t.pump(const Duration(seconds: 1));
    await closeCatalog(t);

    // Menú sin foto, perfil: agregar foto.
    await openMenu(t);
    await pumpUntil(t, find.text('Menú'));
    await shot(t, 'menu-sin-foto');
    await t.tap(find.byTooltip('Cerrar menú'));
    await t.pump(const Duration(seconds: 1));
    await menuTo(t, 'Mi perfil');
    await pumpUntil(t, find.byKey(const Key('profile-photo-change')));
    await shot(t, 'perfil-sin-foto');
    await tapKey(t, 'profile-photo-change');
    await pumpUntil(t, find.byKey(const Key('photo-source-gallery')));
    await shot(t, 'perfil-origen');
    await tapKey(t, 'photo-source-gallery');
    await pumpUntil(t, find.text('Cambiar foto'), seconds: 40);
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'perfil-con-foto');
    await back(t);
    await openMenu(t);
    await pumpUntil(t, find.text('Menú'));
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'menu-con-foto');
    await t.tap(find.byTooltip('Cerrar menú'));
    await t.pump(const Duration(seconds: 1));

    // Alta de reclamo con foto (deja un reclamo nuevo en la base: sólo con
    // --dart-define=CREAR_RECLAMO=true).
    if (crearReclamo) {
      await menuTo(t, 'Mis pedidos');
      final entregado = find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').toUpperCase() == 'ENTREGADO');
      await pumpUntil(t, entregado, seconds: 40);
      await tapF(t, entregado);
      await pumpUntil(t, find.text('Hacer un reclamo'));
      await tapText(t, 'Hacer un reclamo');
      await pumpUntil(t, find.byKey(const Key('claim-photo-gallery')));
      await type(t, byHint('Contá brevemente qué pasó'), 'Prueba con foto');
      await tapKey(t, 'claim-photo-gallery');
      await pumpUntil(t, find.byKey(const Key('claim-photo-preview')));
      await shot(t, 'reclamo-con-foto');
      await tapText(t, 'Enviar reclamo');
      await pumpUntil(t, find.text('Reclamo enviado'), seconds: 40);
      await shot(t, 'reclamo-enviado');
      await tapText(t, 'Aceptar');
      await back(t);
      await back(t);
    }

    // Foto de un reclamo existente, desde su detalle.
    await menuTo(t, 'Mis reclamos');
    await pumpUntil(t, find.text('Prueba con foto'), seconds: 40);
    await shot(t, 'reclamos-lista');
    await t.ensureVisible(find.text('Prueba con foto').last);
    await t.tap(find.text('Prueba con foto').last);
    await t.pump(const Duration(seconds: 1));
    await pumpUntil(t, find.byKey(const Key('claim-photo-add')), seconds: 40);
    await shot(t, 'reclamo-detalle-antes');
    await tapKey(t, 'claim-photo-add');
    await pumpUntil(t, find.byKey(const Key('photo-source-gallery')));
    await tapKey(t, 'photo-source-gallery');
    await pumpUntil(t, find.byKey(const Key('claim-photo')), seconds: 40);
    await pumpUntil(t, find.text('Cambiar foto'), seconds: 40);
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'reclamo-detalle-foto');
    await back(t);
    await back(t);

    // Cerrar sesión con la foto puesta y entrar con otra cuenta: no se ve.
    Future<void> cerrarSesion() async {
      await openMenu(t);
      await tapText(t, 'Cerrar sesión');
      await pumpUntil(t, find.text('¿Querés cerrar sesión?'));
      await t.tap(find.text('Cerrar sesión').last);
      await pumpUntil(t, find.text('¡Hola!'));
    }

    await cerrarSesion();
    await login(t, otraCuenta, 'Test1234');
    await openMenu(t);
    await pumpUntil(t, find.text('Menú'));
    await t.pump(const Duration(seconds: 3));
    await shot(t, 'otra-cuenta-menu');
    expect(find.byKey(const Key('avatar-initials')), findsOneWidget);
    await t.tap(find.byTooltip('Cerrar menú'));
    await t.pump(const Duration(seconds: 1));
    await menuTo(t, 'Mi perfil');
    await pumpUntil(t, find.text('Agregar foto'));
    await t.pump(const Duration(seconds: 2));
    await shot(t, 'otra-cuenta-perfil-sin-foto');
    expect(find.text('Cambiar foto'), findsNothing);
    await back(t);
    await cerrarSesion();
    await login(t, 'cliente@splg.com', 'Test1234');

    // Quitar la foto de perfil.
    await menuTo(t, 'Mi perfil');
    await pumpUntil(t, find.byKey(const Key('profile-photo-remove')));
    await tapKey(t, 'profile-photo-remove');
    await pumpUntil(t, find.text('Agregar foto'), seconds: 40);
    await shot(t, 'perfil-foto-quitada');
  });
}
