import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/domain/repository/gascylinder_repository.dart';
import 'package:splg_customer/data/datasource/gascylinder_remote_datasource.dart';

class GasCylinderRepositoryImp implements GasCylinderRepository {
  GasCylinderRepositoryImp(this._remoteDatasource);

  final GasCylinderRemoteDatasource _remoteDatasource;

  /// Foto firmada de cada garrafa del último catálogo (`photoUrl` del back, con
  /// vencimiento), por id. Sin foto, no figura.
  final Map<String, SignedUrl> photos = {};

  /// Lanza ante cualquier error (red, estado o formato).
  @override
  Future<List<GasCylinder>> getGasCylinders() async {
    final data = await _remoteDatasource.getGasCylinders();
    final jsonList = (data as Map<String, dynamic>)['gasCylinders'] as List;
    photos.clear();
    for (final e in jsonList) {
      final photo = SignedUrl.fromPresigned((e as Map)['photoUrl']);
      final id = e['gas_cylinder_id']?.toString();
      if (photo != null && id != null) photos[id] = photo;
    }
    return jsonList.map((e) => GasCylinder.fromJson(e)).toList();
  }

  @override
  final Set<String> outOfStock = {};

  /// Lanza ante cualquier error. El catálogo público nombra distinto los
  /// campos (`id`, `inStock`, `promotions` siempre lista): se pasan al formato
  /// de [GasCylinder] y se guardan las fotos y los agotados.
  @override
  Future<List<GasCylinder>> getPublicCatalog() async {
    final data = await _remoteDatasource.getPublicCatalog();
    final products = data['products'] as List;
    photos.clear();
    outOfStock.clear();
    final out = <GasCylinder>[];
    for (final e in products) {
      final p = e as Map<String, dynamic>;
      final id = p['id'].toString();
      final photo = SignedUrl.fromPresigned(p['photoUrl']);
      if (photo != null) photos[id] = photo;
      if (p['inStock'] != true) outOfStock.add(id);
      out.add(GasCylinder.fromJson({
        'gas_cylinder_id': id,
        'type': p['type'],
        'weight': p['weight'],
        'price': p['price'],
        'description': p['description'] ?? '',
        'isActive': true,
        'promotions': p['promotions'],
      }));
    }
    return out;
  }
}
