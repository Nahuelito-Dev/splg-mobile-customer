import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'consumption_viewmodel.dart';

/// Pantalla "Mi consumo" del perfil.
class ConsumptionView extends StackedView<ConsumptionViewModel> {
  const ConsumptionView({super.key});

  @override
  ConsumptionViewModel viewModelBuilder(BuildContext context) =>
      ConsumptionViewModel();

  @override
  void onViewModelReady(ConsumptionViewModel viewModel) => viewModel.load();

  @override
  Widget builder(
      BuildContext context, ConsumptionViewModel model, Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    return LoadScaffold(
      title: 'Mi consumo',
      model: model,
      builder: (context) {
        final c = model.consumption;
        final next = model.nextRepurchaseLabel;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (c.declared) ...[
              Text(
                  'Declarado: ${_kg(c.avgMonthlyConsumptionKg!)} kg por mes'
                  '${c.cylinderType == null ? '' : ' · ${c.cylinderType}'}',
                  key: const Key('consumption-current'),
                  style: type.value),
              if (next != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Próxima recompra estimada: $next',
                      key: const Key('consumption-next'), style: type.body),
                ),
            ] else
              Text('Todavía no declaraste cuánto gas consumís por mes.',
                  key: const Key('consumption-empty'), style: type.body),
            const SizedBox(height: 18),
            Text('Garrafa habitual', style: type.label),
            const SizedBox(height: 6),
            if (model.cylinders.isEmpty)
              Text('No hay garrafas para elegir.', style: type.caption)
            else
              SplgChoiceChips(
                labels: [for (final g in model.cylinders) g.label],
                selected: model.cylinders
                    .indexWhere((g) => g.id == model.selectedCylinderId),
                onSelected: (i) => model.selectCylinder(model.cylinders[i].id),
              ),
            if (model.cylinderError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(model.cylinderError!,
                    style: type.caption.copyWith(color: brasa.danger)),
              ),
            const SizedBox(height: 14),
            Text('Garrafas por mes', style: type.label),
            const SizedBox(height: 6),
            SplgTextField(
              key: const Key('consumption-quantity'),
              controller: model.quantity,
              enabled: !model.isBusy,
              hint: 'Ej.: 2',
              errorText: model.quantityError,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            if (model.saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(model.saveError!,
                    key: const Key('consumption-error'),
                    style: type.body.copyWith(color: brasa.danger)),
              ),
            if (model.saved)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Guardamos tu consumo.',
                    key: const Key('consumption-saved'),
                    style: type.body.copyWith(color: brasa.success)),
              ),
            const SizedBox(height: 16),
            SplgButton(
              key: const Key('consumption-save'),
              title: 'Guardar',
              loading: model.isBusy,
              onPressed: model.save,
            ),
          ],
        );
      },
    );
  }

  String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
