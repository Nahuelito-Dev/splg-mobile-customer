import 'package:splg_lib/splg_lib.dart';

abstract interface class GasCylinderRepository {
  Future<List<GasCylinder>> getGasCylinders();
}
