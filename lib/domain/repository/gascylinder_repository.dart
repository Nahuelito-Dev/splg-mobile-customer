import 'package:jennygas_lib/jennygas_lib.dart';

abstract interface class GasCylinderRepository {
  Future<List<GasCylinder>> getGasCylinders();
}
