import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/ui/views/public_catalog/public_catalog_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockGasCylinderService gas;
  late MockNavigationService nav;

  setUp(() {
    registerServices();
    gas = locator<GasCylinderService>() as MockGasCylinderService;
    nav = locator<NavigationService>() as MockNavigationService;
    when(gas.getPublicCatalog()).thenAnswer(
        (_) async => [cylinder(), cylinder(id: 'g2', type: 'Garrafa 15kg')]);
    when(gas.outOfStock).thenReturn({'g2'});
  });
  tearDown(() => locator.reset());

  test('carga el catálogo público', () async {
    final model = PublicCatalogViewModel();
    await model.initialize();
    expect(model.cylinders.map((c) => c.id), ['g1', 'g2']);
    expect(model.loadError, isNull);
    expect(model.isBusy, isFalse);
    expect(model.soldOut('g2'), isTrue);
    expect(model.soldOut('g1'), isFalse);
  });

  test('si falla la carga lo dice y deja reintentar', () async {
    when(gas.getPublicCatalog()).thenAnswer((_) async => throw Exception('x'));
    final model = PublicCatalogViewModel();
    await model.initialize();
    expect(model.loadError, isNotNull);
    when(gas.getPublicCatalog()).thenAnswer((_) async => [cylinder()]);
    await model.initialize();
    expect(model.loadError, isNull);
    expect(model.cylinders, hasLength(1));
  });

  test('arma una selección local; una garrafa sin stock no se suma', () async {
    final model = PublicCatalogViewModel();
    await model.initialize();
    expect(model.actionLabel, 'Iniciar sesión o registrarme');
    model
      ..change(model.cylinders[0], 1)
      ..change(model.cylinders[0], 1)
      ..change(model.cylinders[1], 1);
    expect(model.quantityOf('g1'), 2);
    expect(model.quantityOf('g2'), 0);
    expect(model.actionLabel, 'Pedir · 2 garrafas');
    model
      ..change(model.cylinders[0], -1)
      ..change(model.cylinders[0], -1)
      ..change(model.cylinders[0], -1);
    expect(model.hasSelection, isFalse);
  });

  test('Pedir guarda la selección y lleva al login', () async {
    final model = PublicCatalogViewModel();
    await model.initialize();
    model.change(model.cylinders[0], 3);
    await model.continueToLogin();
    verify(gas.savePendingSelection({'g1': 3})).called(1);
    verify(nav.navigateToLoginView()).called(1);
  });

  test('sin elegir nada, entrar al login no guarda nada', () async {
    final model = PublicCatalogViewModel();
    await model.initialize();
    await model.continueToLogin();
    verify(gas.savePendingSelection(<String, int>{})).called(1);
    verify(nav.navigateToLoginView()).called(1);
  });
}
