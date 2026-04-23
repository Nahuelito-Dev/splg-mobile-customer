import 'package:jennygas_lib/domain/gas_cylinder.dart';
import 'package:jennigas_customer/domain/repository/gascylinder_repository.dart';

class FetchGasCylindersUseCase {
  FetchGasCylindersUseCase(this._gascylinderRepository);

  final GasCylinderRepository _gascylinderRepository;

  Future<List<GasCylinder>> call() async =>
      await _gascylinderRepository.getGasCylinders();
}
