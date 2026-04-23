import 'package:jennygas_lib/domain/gas_cylinder.dart';
import 'package:jennigas_customer/domain/usecases/fetch_gascylinders_usecases.dart';
import 'package:jennigas_customer/data/repository/gascylinder_repository_imp.dart';
import 'package:jennigas_customer/data/datasource/gascylinder_remote_datasource.dart';

class GasCylinderService {
  GasCylinderService() {
    _gascylinderRepository = GasCylinderRepositoryImp(_gasCylinderDatasource);
    _fetchGasCylindersUseCase =
        FetchGasCylindersUseCase(_gascylinderRepository);
  }

  final _gasCylinderDatasource = GasCylinderRemoteDatasource();
  late GasCylinderRepositoryImp _gascylinderRepository;
  late FetchGasCylindersUseCase _fetchGasCylindersUseCase;

  final List<GasCylinder> _gasCylinder = [];
  List<GasCylinder> get gasCylinder => _gasCylinder;

  Future<List<GasCylinder>> getGasCylinders() async {
    final gasCylinders = await _fetchGasCylindersUseCase();

    _gasCylinder.clear();
    _gasCylinder.addAll(gasCylinders);

    return _gasCylinder;
  }
}
