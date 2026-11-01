import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'repurchase_notice_viewmodel.dart';

/// Pantalla "Aviso de recompra" del perfil.
class RepurchaseNoticeView extends StackedView<RepurchaseNoticeViewModel> {
  const RepurchaseNoticeView({super.key});

  @override
  RepurchaseNoticeViewModel viewModelBuilder(BuildContext context) =>
      RepurchaseNoticeViewModel();

  @override
  void onViewModelReady(RepurchaseNoticeViewModel viewModel) =>
      viewModel.load();

  @override
  Widget builder(BuildContext context, RepurchaseNoticeViewModel model,
      Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    return LoadScaffold(
      title: 'Aviso de recompra',
      model: model,
      builder: (context) {
        final notice = model.notice;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(model.estimateText,
                key: const Key('repurchase-estimate'), style: type.value),
            const SizedBox(height: 18),
            SwitchListTile(
              key: const Key('repurchase-enabled'),
              contentPadding: EdgeInsets.zero,
              title: Text('Avisarme cuando me quede poco gas',
                  style: type.label),
              subtitle: Text(
                  notice.enabled
                      ? 'Te mandamos un aviso con tu pedido habitual listo.'
                      : 'No te vamos a avisar. Tu fecha estimada se sigue calculando.',
                  style: type.caption),
              value: notice.enabled,
              onChanged: model.isBusy ? null : model.setEnabled,
            ),
            if (notice.enabled) ...[
              const SizedBox(height: 10),
              Text(model.daysText,
                  key: const Key('repurchase-days-text'), style: type.body),
              const SizedBox(height: 14),
              Text('Días de aviso', style: type.label),
              const SizedBox(height: 6),
              SplgTextField(
                key: const Key('repurchase-days'),
                controller: model.days,
                enabled: !model.isBusy,
                hint: 'De $repurchaseNoticeMinDays a $repurchaseNoticeMaxDays',
                errorText: model.daysError,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SplgButton(
                key: const Key('repurchase-save'),
                title: 'Guardar',
                loading: model.isBusy,
                onPressed: model.saveDays,
              ),
              if (!notice.usesDistributorDays)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SplgButton(
                    key: const Key('repurchase-use-default'),
                    title: 'Usar el de la distribuidora',
                    style: SplgButtonStyle.outlined,
                    onPressed: model.isBusy ? null : model.useDistributorDays,
                  ),
                ),
            ],
            if (model.saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(model.saveError!,
                    key: const Key('repurchase-error'),
                    style: type.body.copyWith(color: brasa.danger)),
              ),
            if (model.saved)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Guardamos tus preferencias.',
                    key: const Key('repurchase-saved'),
                    style: type.body.copyWith(color: brasa.success)),
              ),
          ],
        );
      },
    );
  }
}
