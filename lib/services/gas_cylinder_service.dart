import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_customer/domain/payment_term.dart';
import 'package:splg_customer/domain/usecases/fetch_gascylinders_usecases.dart';
import 'package:splg_customer/data/repository/gascylinder_repository_imp.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';

class GasCylinderService {
  GasCylinderService({
    GasCylinderRemoteDatasource? datasource,
    DateTime Function()? clock,
  })  : _gasCylinderDatasource = datasource ?? GasCylinderRemoteDatasource(),
        _clock = clock ?? DateTime.now {
    _gascylinderRepository = GasCylinderRepositoryImp(_gasCylinderDatasource);
    _fetchGasCylindersUseCase =
        FetchGasCylindersUseCase(_gascylinderRepository);
  }

  final GasCylinderRemoteDatasource _gasCylinderDatasource;
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

  /// La garrafa tiene foto en el último catálogo (vigente o vencida).
  bool hasPhoto(String id) => _gascylinderRepository.photos.containsKey(id);

  /// Espera mínima entre dos pedidos del catálogo para renovar fotos: una foto
  /// que falla aun recién firmada no arma un bucle de pedidos.
  static const photoRenewalCooldown = Duration(seconds: 30);

  /// Reloj de la renovación; los tests lo fijan.
  final DateTime Function() _clock;

  bool _lastWasPublic = false;
  DateTime? _lastPhotoRenewal;
  Future<bool>? _renewing;

  /// Vuelve a pedir el último catálogo (el público o el de la distribuidora)
  /// para renovar las URLs firmadas de las fotos, que vencen a los pocos
  /// minutos: cuando alguna venció o cuando falló la carga de [failedUrl].
  /// Un pedido a la vez y no más de uno cada [photoRenewalCooldown].
  /// Devuelve true si hay fotos nuevas para mostrar.
  Future<bool> renewPhotos({String? failedUrl}) {
    final pending = _renewing;
    if (pending != null) return pending;
    final photos = _gascylinderRepository.photos.values;
    if (failedUrl != null) {
      // La que falló ya se reemplazó: alcanza con repintar.
      if (!photos.any((p) => p.url == failedUrl)) return Future.value(true);
    } else if (!hasExpiredPhotos) {
      return Future.value(false);
    }
    final now = _clock();
    final last = _lastPhotoRenewal;
    if (last != null && now.difference(last) < photoRenewalCooldown) {
      return Future.value(false);
    }
    _lastPhotoRenewal = now;
    final load = _lastWasPublic ? getPublicCatalog() : getGasCylinders();
    return _renewing = load
        .then((_) => true, onError: (_) => false)
        .whenComplete(() => _renewing = null);
  }

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
    _lastWasPublic = true;
    final gasCylinders = await _gascylinderRepository.getPublicCatalog();
    _gasCylinder
      ..clear()
      ..addAll(sortedByWeight(gasCylinders));
    return _gasCylinder;
  }

  Future<List<GasCylinder>> getGasCylinders() async {
    _lastWasPublic = false;
    final gasCylinders = await _fetchGasCylindersUseCase();

    _gasCylinder.clear();
    _gasCylinder.addAll(sortedByWeight(gasCylinders));

    return _gasCylinder;
  }
}
