import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/app_info.dart';

import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/claims/claims_view.dart';
import 'package:splg_customer/ui/widgets/app_header.dart';
import 'package:splg_customer/ui/widgets/photo_source_sheet.dart';
import 'package:splg_customer/ui/widgets/signed_image.dart';
import 'claim_detail_viewmodel.dart';
import 'package:splg_customer/ui/common/app_icons.dart';

/// Detalle de un reclamo propio: motivo, descripción, estado y la nota con la
/// que se resolvió.
class ClaimDetailView extends StackedView<ClaimDetailViewModel> {
  const ClaimDetailView({super.key, required this.claim});

  final MyClaim claim;

  @override
  ClaimDetailViewModel viewModelBuilder(BuildContext context) =>
      ClaimDetailViewModel(claim.claimId, claim.status);

  @override
  void onViewModelReady(ClaimDetailViewModel viewModel) =>
      viewModel.loadPhoto();

  @override
  Widget builder(
      BuildContext context, ClaimDetailViewModel model, Widget? child) {
    final type = SplgType.of(context);
    return Scaffold(
      appBar: const AppHeader(title: 'Reclamo', bell: false),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SplgSectionBar(
                  title: dateTimeLabel(claim.createdAt),
                  trailing: claim.status.label.toUpperCase()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(claim.reason, style: type.heading)),
                        const SizedBox(width: 10),
                        SplgStatusBadge(
                            label: claim.status.label,
                            tone: claimTone(claim.status)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(claim.description, style: type.body),
                    if (model.photoUrl != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SignedImage(
                          key: const Key('claim-photo'),
                          url: model.photoUrl,
                          fit: BoxFit.cover,
                          height: 220,
                          fallback: const SizedBox(height: 220),
                        ),
                      ),
                    ],
                    if (model.canAttach && !model.loadingPhoto)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('claim-photo-add'),
                          onPressed: model.busy('photo')
                              ? null
                              : () async {
                                  final source =
                                      await choosePhotoSource(context);
                                  if (source != null) {
                                    await model.attach(source);
                                  }
                                },
                          icon: model.busy('photo')
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(AppIcons.camera, size: 18),
                          label: Text(
                              model.hasPhoto ? 'Cambiar foto' : 'Agregar foto'),
                        ),
                      ),
                    if (model.photoError != null)
                      Text(model.photoError!,
                          key: const Key('claim-photo-error'),
                          style: type.caption
                              .copyWith(color: context.brasa.danger)),
                    const SizedBox(height: 16),
                    AppInfoSection(
                      icon: SplgIcons.deliveries,
                      title: 'Pedido reclamado',
                      rows: [
                        AppInfoRow(
                            title: 'Código:',
                            value: claim.orderId.length > 6
                                ? '#${claim.orderId.substring(claim.orderId.length - 6)}'
                                : claim.orderId),
                        if (claim.orderTotal != null)
                          AppInfoRow(
                              title: 'Total:',
                              value: money.format(claim.orderTotal!)),
                      ],
                    ),
                    if ((claim.resolutionNote ?? '').isNotEmpty)
                      AppInfoSection(
                        icon: SplgIcons.ok,
                        title: 'Respuesta de la distribuidora',
                        rows: [
                          AppInfoRow(
                              title: 'Nota:', value: claim.resolutionNote)
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
