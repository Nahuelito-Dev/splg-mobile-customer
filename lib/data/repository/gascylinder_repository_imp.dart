import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_customer/domain/repository/gascylinder_repository.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';

class GasCylinderRepositoryImp implements GasCylinderRepository {
  GasCylinderRepositoryImp(this._remoteDatasource);

  final GasCylinderRemoteDatasource _remoteDatasource;

  /// Lanza ante cualquier error (red, estado o formato).
  @override
  Future<List<GasCylinder>> getGasCylinders() async {
    final data = await _remoteDatasource.getGasCylinders();
    final jsonList = (data as Map<String, dynamic>)['gasCylinders'] as List;
    return jsonList.map((e) => GasCylinder.fromJson(e)).toList();
  }
}
