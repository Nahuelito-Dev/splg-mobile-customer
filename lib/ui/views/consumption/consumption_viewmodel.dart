import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/gas_cylinder.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/consumption_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Mi consumo (CU-144): ver el promedio declarado y la próxima recompra
/// estimada, y corregirlo.
class ConsumptionViewModel extends LoadViewModel {
  final _service = locator<ConsumptionService>();
  final _cylinderService = locator<GasCylinderService>();
  final _dialogs = locator<DialogService>();

  final quantity = TextEditingController();

  Consumption consumption = const Consumption();
  List<GasCylinder> cylinders = [];
  String? selectedCylinderId;

  String? quantityError;
  String? cylinderError;

  /// Error del guardado, bajo el formulario.
  String? saveError;

  /// Se guardó recién: avisa con un texto breve.
  bool saved = false;

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Future<void> fetch() async {
    final r = await _service.fetch();
    if (!r.ok) throw LoadFailure(r.message!);
    consumption = r.data!;
    cylinders = await _cylinderService.getGasCylinders();
    selectedCylinderId ??= cylinders
        .where((c) => c.id == consumption.cylinderTypeId)
        .map((c) => c.id)
        .firstOrNull;
  }

  void selectCylinder(String id) {
    selectedCylinderId = id;
    cylinderError = null;
    saved = false;
    notifyListeners();
  }

  /// Próxima recompra estimada, lista para mostrar; null si no hay.
  String? get nextRepurchaseLabel {
    final d = consumption.nextRepurchaseEstimateAt;
    return d == null ? null : DateFormat('dd/MM/yyyy', 'es_AR').format(d);
  }

  Future<void> save() async {
    if (isBusy) return;
    saved = false;
    saveError = null;
    final qty = parseQuantityPerMonth(quantity.text);
    quantityError = qty == null
        ? 'Ingresá cuántas garrafas consumís por mes (de 0,01 a 1000).'
        : null;
    cylinderError =
        selectedCylinderId == null && consumption.cylinderTypeId == null
            ? 'Elegí tu garrafa habitual.'
            : null;
    if (qty == null || cylinderError != null) {
      notifyListeners();
      return;
    }
    setBusy(true);
    var declaration = ConsumptionDeclaration(
        cylinderTypeId: selectedCylinderId, quantityPerMonth: qty);
    var outcome = await _service.save(declaration);
    if (outcome.status == ConsumptionSaveStatus.needsConfirmation) {
      final answer = await _dialogs.showConfirmationDialog(
        title: 'Consumo fuera de lo habitual',
        description: 'Lo que declaraste queda fuera del rango razonable '
            '($consumptionMinKg a $consumptionMaxKg kg por mes). '
            '¿Querés guardarlo igual?',
        confirmationTitle: 'Guardar igual',
        cancelTitle: 'Corregir',
      );
      if (answer?.confirmed == true) {
        declaration = declaration.confirmed();
        outcome = await _service.save(declaration);
      } else {
        setBusy(false);
        return;
      }
    }
    if (outcome.status == ConsumptionSaveStatus.saved) {
      consumption = outcome.consumption!;
      quantity.clear();
      saved = true;
    } else {
      saveError =
          outcome.message ?? 'No pudimos guardar tu consumo. Probá de nuevo.';
    }
    setBusy(false);
  }
}
