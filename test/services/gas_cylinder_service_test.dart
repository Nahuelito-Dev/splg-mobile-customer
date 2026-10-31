import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import '../helpers/fixtures.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';
import 'package:splg_customer/data/repository/gascylinder_repository_imp.dart';

class _Datasource extends GasCylinderRemoteDatasource {
  _Datasource(this.run);

  final Future<dynamic> Function() run;

  @override
  Future<dynamic> getGasCylinders() => run();
}

void main() {
  test('el catálogo se ordena por peso numérico: 5, 10, 15, 25, 45', () {
    final list = [
      for (final w in ['10', '15', '25', '45', '5'])
        cylinder(id: 'g$w', type: 'Garrafa ${w}kg').copyWith(weight: w),
    ];
    expect(
      GasCylinderService.sortedByWeight(list).map((g) => g.weight),
      ['5', '10', '15', '25', '45'],
    );
  });

  group('Catálogo de garrafas', () {
    test('un error del datasource se propaga, no es una lista vacía', () {
      final repo = GasCylinderRepositoryImp(
          _Datasource(() async => throw Exception('sin red')));
      expect(repo.getGasCylinders(), throwsException);
    });

    test('un cuerpo ilegible se propaga', () {
      final repo =
          GasCylinderRepositoryImp(_Datasource(() async => 'no es un mapa'));
      expect(repo.getGasCylinders(), throwsA(anything));
    });

    test('un catálogo realmente vacío es una lista vacía', () async {
      final repo = GasCylinderRepositoryImp(
          _Datasource(() async => {'gasCylinders': <dynamic>[]}));
      expect(await repo.getGasCylinders(), isEmpty);
    });
  });
}
