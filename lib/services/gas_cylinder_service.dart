import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_customer/domain/payment_term.dart';
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

  /// Del más liviano al más pesado (5, 10, 15, 25, 45). El peso viene como
  /// texto, que ordenado como tal pondría el 5 al final; los que no tienen un
  /// peso numérico quedan al final.
  static List<GasCylinder> sortedByWeight(List<GasCylinder> list) {
    double key(GasCylinder g) =>
        double.tryParse(g.weight.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        double.infinity;
    final sorted = [...list];
    sorted.sort((a, b) => key(a).compareTo(key(b)));
    return sorted;
  }

  /// Sin stock en el último catálogo público.
  Set<String> get outOfStock => _gascylinderRepository.outOfStock;

  /// Lo que eligió en el catálogo público (id de garrafa -> cantidad) antes de
  /// iniciar sesión; el inicio lo pasa al carrito al abrir y lo vacía.
  final Map<String, int> _pendingSelection = {};

  void savePendingSelection(Map<String, int> selection) => _pendingSelection
    ..clear()
    ..addAll(selection);

  /// Entrega lo guardado y lo vacía.
  Map<String, int> takePendingSelection() {
    final taken = Map<String, int>.of(_pendingSelection);
    _pendingSelection.clear();
    return taken;
  }

  /// Los medios de pago con el recargo que cobra hoy la distribuidora (lo
  /// informa el back). Si no se puede leer, devuelve una lista vacía: la app no
  /// menciona ningún recargo que no pueda confirmar.
  Future<List<PaymentTerm>> paymentTerms() async {
    try {
      return PaymentTerm.listFromJson(
          await _gasCylinderDatasource.getPaymentMethods());
    } catch (_) {
      return const [];
    }
  }

  /// Catálogo de la distribuidora sin sesión.
  Future<List<GasCylinder>> getPublicCatalog() async {
    final gasCylinders = await _gascylinderRepository.getPublicCatalog();
    _gasCylinder
      ..clear()
      ..addAll(sortedByWeight(gasCylinders));
    return _gasCylinder;
  }

  Future<List<GasCylinder>> getGasCylinders() async {
    final gasCylinders = await _fetchGasCylindersUseCase();

    _gasCylinder.clear();
    _gasCylinder.addAll(sortedByWeight(gasCylinders));

    return _gasCylinder;
  }
}
