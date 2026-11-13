import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/home/widgets/cylinder_detail_sheet.dart';
import 'package:splg_customer/ui/widgets/signed_image.dart';
import 'public_catalog_viewmodel.dart';

/// «Ver garrafas y precios»: el catálogo de la distribuidora sin iniciar sesión.
class PublicCatalogView extends StackedView<PublicCatalogViewModel> {
  const PublicCatalogView({super.key});

  @override
  void onViewModelReady(PublicCatalogViewModel viewModel) =>
      viewModel.initialize();

  @override
  PublicCatalogViewModel viewModelBuilder(BuildContext context) =>
      PublicCatalogViewModel();

  @override
  Widget builder(
      BuildContext context, PublicCatalogViewModel model, Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    return Scaffold(
      backgroundColor: brasa.surfaceSunken,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('public-catalog-back'),
          tooltip: 'Volver',
          icon: const Icon(SplgIcons.back),
          onPressed: model.back,
        ),
        title: Text('Garrafas y precios', style: type.heading),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              Expanded(child: _content(context, model)),
              const SizedBox(height: 12),
              SplgButton(
                key: const Key('public-catalog-action'),
                title: model.actionLabel,
                style: model.hasSelection
                    ? SplgButtonStyle.filled
                    : SplgButtonStyle.outlined,
                onPressed: model.continueToLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, PublicCatalogViewModel model) {
    if (model.isBusy) return const SplgLoader();
    if (model.loadError != null) {
      return SplgEmptyState(
        illustration: SplgIllustration.error,
        title: 'No pudimos cargar',
        message: model.loadError!,
        action: SplgButton(
          title: 'Reintentar',
          style: SplgButtonStyle.outlined,
          expand: false,
          onPressed: model.initialize,
        ),
      );
    }
    if (model.cylinders.isEmpty) {
      return const SplgEmptyState(
        message: 'Tu distribuidora todavía no cargó garrafas.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: model.cylinders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = model.cylinders[i];
        return SplgProductCard(
          image: SignedImage(
            key: Key('cylinder-photo-${c.id}'),
            url: model.photo(c.id),
            onError: model.photoFailed,
            fallback:
                Image.asset('assets/cylinder_10.png', fit: BoxFit.contain),
          ),
          title: c.label,
          price: money.format(c.price),
          quantity: model.quantityOf(c.id),
          promos: [
            if (model.soldOut(c.id)) 'Sin stock',
            for (final d in Pricing.sortedDiscounts(c)) Pricing.badge(d),
          ],
          onAdd: () => model.change(c, 1),
          onRemove: () => model.change(c, -1),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CylinderDetailSheet(
              cylinder: c,
              photoUrl: model.photo(c.id),
              onAdd: () => model.change(c, 1),
            ),
          ),
        );
      },
    );
  }
}
