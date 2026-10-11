import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'claims_viewmodel.dart';

SplgTone claimTone(ClaimStatus s) => switch (s) {
      ClaimStatus.pending => SplgTone.warn,
      ClaimStatus.inProcess => SplgTone.info,
      ClaimStatus.resolved => SplgTone.success,
      ClaimStatus.rejected => SplgTone.danger,
    };

class ClaimsView extends StackedView<ClaimsViewModel> {
  const ClaimsView({super.key});

  @override
  ClaimsViewModel viewModelBuilder(BuildContext context) => ClaimsViewModel();

  @override
  void onViewModelReady(ClaimsViewModel viewModel) => viewModel.load();

  @override
  Widget builder(BuildContext context, ClaimsViewModel model, Widget? child) {
    final type = SplgType.of(context);
    return LoadScaffold(
      title: 'Mis reclamos',
      model: model,
      builder: (context) {
        if (model.claims.isEmpty) {
          return const SplgEmptyState(
            illustration: SplgIllustration.claim,
            message: 'No hiciste ningún reclamo. Si tenés un problema con un '
                'pedido, abrilo desde "Mis pedidos".',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (final c in model.claims)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SplgOrderCard(
                  key: Key('claim-${c.claimId}'),
                  icon: SplgIcons.claim,
                  title: c.reason,
                  subtitle: dateTimeLabel(c.createdAt),
                  detail: c.description,
                  badge: c.status.label.toUpperCase(),
                  badgeTone: claimTone(c.status),
                  onTap: () => model.open(c),
                ),
              ),
            if (model.moreError != null)
              Text(model.moreError!,
                  style: type.body.copyWith(color: context.brasa.danger)),
            if (model.hasMore)
              SplgButton(
                title: 'Ver más',
                style: SplgButtonStyle.outlined,
                loading: model.loadingMore,
                onPressed: model.loadMore,
              ),
          ],
        );
      },
    );
  }
}
