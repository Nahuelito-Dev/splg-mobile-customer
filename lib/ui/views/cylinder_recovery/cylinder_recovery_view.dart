import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/cylinder_recovery.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'cylinder_recovery_viewmodel.dart';

/// Pantalla "Envases para devolver" del menú.
class CylinderRecoveryView extends StackedView<CylinderRecoveryViewModel> {
  const CylinderRecoveryView({super.key});

  @override
  CylinderRecoveryViewModel viewModelBuilder(BuildContext context) =>
      CylinderRecoveryViewModel();

  @override
  void onViewModelReady(CylinderRecoveryViewModel viewModel) =>
      viewModel.initialize();

  @override
  Widget builder(BuildContext context, CylinderRecoveryViewModel model,
      Widget? child) {
    return LoadScaffold(
      title: 'Envases para devolver',
      model: model,
      builder: (context) {
        if (model.cases.isEmpty) {
          return const SplgEmptyState(
            illustration: SplgIllustration.emptyList,
            message: 'No tenés envases pendientes de devolución.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (final c in model.cases)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CaseCard(model: model, recovery: c),
              ),
          ],
        );
      },
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.model, required this.recovery});

  final CylinderRecoveryViewModel model;
  final RecoveryCase recovery;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final c = recovery;
    final pickup = c.pickup;
    final answering = model.isAnswering(c);
    return Container(
      key: Key('recovery-${c.caseId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: brasa.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.serial, style: type.value),
          if (c.product != null) Text(c.product!, style: type.caption),
          const SizedBox(height: 6),
          Text(model.daysOutText(c), style: type.body),
          const SizedBox(height: 4),
          Text(model.stepText(c), style: type.caption),
          if (pickup != null) ...[
            const SizedBox(height: 12),
            if (pickup.accepted) ...[
              Text(
                  'Lo retira el repartidor con tu próxima entrega'
                  '${model.pickupDay(pickup) == null ? '' : ' (${model.pickupDay(pickup)})'}. '
                  'Dejalo listo.',
                  key: Key('recovery-accepted-${c.caseId}'),
                  style: type.body.copyWith(color: brasa.success)),
              TextButton(
                onPressed: () => model.openOrder(pickup),
                child: const Text('Ver el pedido'),
              ),
            ] else ...[
              Text(
                  'Podés devolverlo cuando te entreguemos tu próximo pedido'
                  '${model.pickupDay(pickup) == null ? '' : ' (${model.pickupDay(pickup)})'}.',
                  style: type.body),
              const SizedBox(height: 10),
              SplgButton(
                key: Key('recovery-accept-${c.caseId}'),
                title: 'Lo devuelvo en mi entrega',
                loading: answering,
                onPressed:
                    model.answeringCaseId != null ? null : () => model.acceptPickup(c),
              ),
              const SizedBox(height: 8),
              SplgButton(
                key: Key('recovery-decline-${c.caseId}'),
                title: 'Ahora no',
                style: SplgButtonStyle.outlined,
                onPressed:
                    model.answeringCaseId != null ? null : () => model.declinePickup(c),
              ),
            ],
          ],
          if (model.answerErrorCaseId == c.caseId && model.answerError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(model.answerError!,
                  key: Key('recovery-error-${c.caseId}'),
                  style: type.body.copyWith(color: brasa.danger)),
            ),
        ],
      ),
    );
  }
}
