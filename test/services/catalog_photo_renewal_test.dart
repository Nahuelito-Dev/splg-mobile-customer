import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/ui/common/catalog_photos.dart';
import 'package:splg_customer/ui/views/public_catalog/public_catalog_viewmodel.dart';
import 'package:splg_customer/ui/widgets/signed_image.dart';

import '../helpers/test_helpers.dart';

/// Las fotos del catálogo vienen con URL firmada de S3 que vence a los 300 s:
/// la app vuelve a pedir el catálogo cuando vencieron o cuando falla la carga
/// de la imagen, sin bucles (un pedido a la vez y uno cada 30 s como mucho).

/// URL prefirmada como la del back, firmada [ago] atrás y válida 300 s.
String presigned(String name, Duration ago) {
  final t = DateTime.now().toUtc().subtract(ago);
  String two(int n) => n.toString().padLeft(2, '0');
  final amzDate = '${t.year}${two(t.month)}${two(t.day)}T'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  return 'https://s3.test/$name.png?X-Amz-Date=$amzDate&X-Amz-Expires=300';
}

class _Datasource extends GasCylinderRemoteDatasource {
  /// Antigüedad de la firma de lo que devuelve el próximo pedido.
  Duration signedAgo = Duration.zero;
  int privateCalls = 0;
  int publicCalls = 0;
  Completer<void>? gate;

  /// Cuántos de los próximos pedidos del catálogo público fallan (red caída).
  int failPublic = 0;

  @override
  Future<dynamic> getGasCylinders() async {
    privateCalls++;
    await gate?.future;
    return {
      'gasCylinders': [
        {
          'gas_cylinder_id': 'g1',
          'type': 'Garrafa 10kg',
          'weight': '10',
          'price': 1000,
          'isActive': true,
          'description': '',
          'promotions': [],
          'photoUrl': presigned('g1-$privateCalls', signedAgo),
        }
      ],
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> getPublicCatalog() async {
    publicCalls++;
    await gate?.future;
    if (failPublic > 0) {
      failPublic--;
      throw Exception('sin red');
    }
    return {
      'products': [
        {
          'id': 'g1',
          'type': 'Garrafa 10kg',
          'weight': '10',
          'price': 1000,
          'inStock': true,
          'promotions': [],
          'photoUrl': presigned('pub-$publicCalls', signedAgo),
        }
      ],
    };
  }
}

void main() {
  late _Datasource ds;
  late DateTime now;
  late GasCylinderService service;

  setUp(() {
    ds = _Datasource();
    now = DateTime(2026, 11, 12, 9);
    service = GasCylinderService(datasource: ds, clock: () => now);
  });

  group('GasCylinderService.renewPhotos', () {
    test('con la foto vigente no vuelve a pedir el catálogo', () async {
      await service.getGasCylinders();
      expect(service.photoUrl('g1'), contains('g1-1'));

      expect(await service.renewPhotos(), isFalse);
      expect(ds.privateCalls, 1);
    });

    test('con la foto vencida pide el catálogo y trae la URL nueva', () async {
      ds.signedAgo = const Duration(minutes: 10);
      await service.getGasCylinders();
      expect(service.photoUrl('g1'), isNull);
      expect(service.hasPhoto('g1'), isTrue);

      ds.signedAgo = Duration.zero;
      expect(await service.renewPhotos(), isTrue);
      expect(ds.privateCalls, 2);
      expect(service.photoUrl('g1'), contains('g1-2'));
    });

    test('si falla la descarga de la URL vigente la vuelve a pedir', () async {
      await service.getGasCylinders();
      final failed = service.photoUrl('g1')!;

      expect(await service.renewPhotos(failedUrl: failed), isTrue);
      expect(ds.privateCalls, 2);
      expect(service.photoUrl('g1'), isNot(failed));
    });

    test(
        'sin bucles: una foto que falla aun recién firmada no se pide más de '
        'una vez cada 30 s', () async {
      await service.getGasCylinders();
      await service.renewPhotos(failedUrl: service.photoUrl('g1'));
      expect(ds.privateCalls, 2);

      // La nueva también falla enseguida: no se pide de nuevo.
      now = now.add(const Duration(seconds: 5));
      expect(await service.renewPhotos(failedUrl: service.photoUrl('g1')),
          isFalse);
      expect(ds.privateCalls, 2);

      now = now.add(GasCylinderService.photoRenewalCooldown);
      expect(
          await service.renewPhotos(failedUrl: service.photoUrl('g1')), isTrue);
      expect(ds.privateCalls, 3);
    });

    test('una URL que ya se reemplazó no pide el catálogo: sólo repinta',
        () async {
      await service.getGasCylinders();
      final old = service.photoUrl('g1')!;
      await service.renewPhotos(failedUrl: old);
      now = now.add(const Duration(minutes: 5));

      expect(await service.renewPhotos(failedUrl: old), isTrue);
      expect(ds.privateCalls, 2);
    });

    test('varias fotos vencidas a la vez arman un solo pedido', () async {
      ds.signedAgo = const Duration(minutes: 10);
      await service.getGasCylinders();
      ds.gate = Completer<void>();

      final a = service.renewPhotos();
      final b = service.renewPhotos();
      ds.gate!.complete();
      expect(await Future.wait([a, b]), [true, true]);
      expect(ds.privateCalls, 2);
    });

    test('sin sesión renueva con el catálogo público', () async {
      ds.signedAgo = const Duration(minutes: 10);
      await service.getPublicCatalog();
      ds.signedAgo = Duration.zero;

      expect(await service.renewPhotos(), isTrue);
      expect(ds.publicCalls, 2);
      expect(ds.privateCalls, 0);
      expect(service.photoUrl('g1'), contains('pub-2'));
    });
  });

  group('pantalla del catálogo', () {
    setUp(() {
      registerServices();
      locator.unregister<GasCylinderService>();
      locator.registerSingleton<GasCylinderService>(service);
    });
    tearDown(() => locator.reset());

    testWidgets(
        'una foto vencida se renueva después del cuadro, no desde el build',
        (tester) async {
      ds.signedAgo = const Duration(minutes: 10);
      final model = PublicCatalogViewModel();
      await tester.runAsync(model.initialize);
      var repaints = 0;
      model.addListener(() => repaints++);
      ds.signedAgo = Duration.zero;

      expect(model.photo('g1'), isNull);
      expect(model.photo('g1'), isNull);
      // Pedirla desde el build no dispara nada en el momento.
      expect(ds.publicCalls, 1);

      await tester.pump();
      await tester.runAsync(pumpEventQueue);

      expect(ds.publicCalls, 2);
      expect(repaints, 1);
      expect(model.photo('g1'), contains('pub-2'));
    });

    test('si la imagen no carga, la pide de nuevo y repinta', () async {
      final model = PublicCatalogViewModel();
      await model.initialize();
      var repaints = 0;
      model.addListener(() => repaints++);

      model.photoFailed(model.photo('g1')!);
      await pumpEventQueue();

      expect(ds.publicCalls, 2);
      expect(repaints, 1);
    });

    test('varias fotos que fallan juntas: un pedido y un solo repintado',
        () async {
      final model = PublicCatalogViewModel();
      await model.initialize();
      var repaints = 0;
      model.addListener(() => repaints++);
      final url = model.photo('g1')!;

      model
        ..photoFailed(url)
        ..photoFailed(url)
        ..photoFailed(url);
      await pumpEventQueue();

      expect(ds.publicCalls, 2);
      expect(repaints, 1);
    });

    testWidgets(
        'si la renovación falla, se reintenta pasada la espera y repinta',
        (tester) async {
      ds.signedAgo = const Duration(minutes: 10);
      final model = PublicCatalogViewModel();
      await model.initialize();
      var repaints = 0;
      model.addListener(() => repaints++);

      ds.failPublic = 1;
      ds.signedAgo = Duration.zero;
      expect(model.photo('g1'), isNull);
      await tester.pump();
      await tester.pump();
      expect(ds.publicCalls, 2);
      expect(repaints, 0);

      // Nada repinta la pantalla: el reintento sale solo.
      now = now.add(GasCylinderService.photoRenewalCooldown);
      await tester.pump(GasCylinderService.photoRenewalCooldown);
      await tester.pump();

      expect(ds.publicCalls, 3);
      expect(repaints, 1);
      expect(model.photo('g1'), contains('pub-3'));
      model.dispose();
    });

    testWidgets(
        'agotados los reintentos, una foto vigente vuelve a habilitarlos',
        (tester) async {
      ds.signedAgo = const Duration(minutes: 10);
      final model = PublicCatalogViewModel();
      await model.initialize();
      ds.failPublic = 1000;

      Future<void> esperarEspera() async {
        now = now.add(GasCylinderService.photoRenewalCooldown);
        await tester.pump(GasCylinderService.photoRenewalCooldown);
        await tester.pump();
      }

      // La foto vencida dispara la renovación; falla y se reintenta sola
      // hasta agotar los reintentos.
      expect(model.photo('g1'), isNull);
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < CatalogPhotos.maxPhotoRetries; i++) {
        await esperarEspera();
      }
      final agotado = ds.publicCalls;
      expect(agotado, 2 + CatalogPhotos.maxPhotoRetries);
      await esperarEspera();
      expect(ds.publicCalls, agotado, reason: 'no hay más reintentos');

      // Otra pantalla renueva el catálogo: la foto vuelve a estar vigente.
      ds.failPublic = 0;
      ds.signedAgo = Duration.zero;
      await service.getPublicCatalog();
      expect(model.photo('g1'), isNotNull);

      // Vence de nuevo y la renovación falla: vuelve a haber reintento.
      ds.signedAgo = const Duration(minutes: 10);
      await service.getPublicCatalog();
      ds.failPublic = 1000;
      final antes = ds.publicCalls;
      expect(model.photo('g1'), isNull);
      await tester.pump();
      await tester.pump();
      await esperarEspera();
      expect(ds.publicCalls, antes + 2);
      model.dispose();
    });

    testWidgets('al cerrar la pantalla se cancela el reintento',
        (tester) async {
      ds.signedAgo = const Duration(minutes: 10);
      final model = PublicCatalogViewModel();
      await model.initialize();

      ds.failPublic = 1;
      model.photoFailed('https://s3.test/otra.png');
      expect(model.photo('g1'), isNull);
      await tester.pump();
      await tester.pump();
      final calls = ds.publicCalls;

      model.dispose();
      now = now.add(GasCylinderService.photoRenewalCooldown);
      await tester.pump(GasCylinderService.photoRenewalCooldown * 2);

      expect(ds.publicCalls, calls);
    });

    test('si la pantalla se cerró mientras se renovaba, no se repinta',
        () async {
      final model = PublicCatalogViewModel();
      await model.initialize();
      var repaints = 0;
      model.addListener(() => repaints++);
      ds.gate = Completer<void>();

      model.photoFailed(model.photo('g1')!);
      model.dispose();
      ds.gate!.complete();
      await pumpEventQueue();

      expect(repaints, 0);
    });
  });

  testWidgets('SignedImage avisa la URL que no pudo cargar', (tester) async {
    final failed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: SignedImage(
        url: 'https://s3.test/rota.png',
        onError: failed.add,
        fallback: const Text('asset'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('asset'), findsOneWidget);
    expect(failed, ['https://s3.test/rota.png']);
  });
}
