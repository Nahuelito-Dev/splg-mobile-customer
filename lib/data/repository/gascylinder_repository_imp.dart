import 'dart:developer';

import 'package:jennygas_lib/domain/gas_cylinder.dart';
import 'package:jennigas_customer/domain/repository/gascylinder_repository.dart';
import 'package:jennigas_customer/data/datasource/gascylinder_remote_datasource.dart';

class GasCylinderRepositoryImp implements GasCylinderRepository {
  GasCylinderRepositoryImp(this._remoteDatasource);

  final GasCylinderRemoteDatasource _remoteDatasource;

  @override
  Future<List<GasCylinder>> getGasCylinders() async {
    try {
      final (success, data) = await _remoteDatasource.getGasCylinders();

      if (success && data != null) {
        final jsonList = (data as Map<String, dynamic>)['gasCylinders'] as List;
        final gasCylinderList =
            jsonList.map((e) => GasCylinder.fromJson(e)).toList();
        return gasCylinderList;
      }
    } catch (e) {
      log('e in getGasCylinders: ${e.toString()}');
    }

    return [];
  }
}
