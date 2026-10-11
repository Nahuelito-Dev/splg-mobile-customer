import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_customer/domain/usecases/fetch_gascylinders_usecases.dart';
import 'package:splg_customer/data/repository/gascylinder_repository_imp.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';

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

  /// Foto firmada de una garrafa si todavía no venció; null = usar el asset.
  String? photoUrl(String id) {
    final p = _gascylinderRepository.photos[id];
    return p != null && p.isValid ? p.url : null;
  }

  /// Hay garrafas con foto cuya URL ya venció (hay que volver a pedir el catálogo).
  bool get hasExpiredPhotos =>
      _gascylinderRepository.photos.values.any((p) => !p.isValid);

  Future<List<GasCylinder>> getGasCylinders() async {
    final gasCylinders = await _fetchGasCylindersUseCase();

    _gasCylinder.clear();
    _gasCylinder.addAll(gasCylinders);

    return _gasCylinder;
  }
}
