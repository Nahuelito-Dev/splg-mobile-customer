import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'cylinder_detail_sheet.dart';

/// Catálogo de garrafas en una hoja expandida sobre el mapa del inicio. Se
/// repinta con el viewmodel (cantidades y total) y "Continuar" lleva al checkout.
Future<void> showCatalogSheet(BuildContext context, HomeViewModel model) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ListenableBuilder(
      listenable: model,
      builder: (ctx, _) => _CatalogSheet(model: model),
    ),
  );
}

class _CatalogSheet extends StatelessWidget {
  const _CatalogSheet({required this.model});

  final HomeViewModel model;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    return SplgBottomPanel(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Elegí tus garrafas', style: type.heading),
            ),
            const SizedBox(height: 8),
            Expanded(child: _content(context)),
            const SizedBox(height: 12),
            SplgButton(
              title: model.canPlaceOrder
                  ? 'Continuar · ${money.format(model.total)}'
                  : 'Elegí tus garrafas',
              onPressed: model.canPlaceOrder
                  ? () {
                      Navigator.of(context).pop();
                      model.placeOrder();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
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
          onPressed: model.reloadCatalog,
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
          image: Image.asset('assets/cylinder_10.png', fit: BoxFit.contain),
          title: c.label,
          price: money.format(c.price),
          quantity: model.getItemQuantity(c.id),
          promos: [
            for (final d in Pricing.sortedDiscounts(c)) Pricing.badge(d)
          ],
          onAdd: () => model.addItem(c, 1),
          onRemove: () => model.addItem(c, -1),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CylinderDetailSheet(
                cylinder: c, onAdd: () => model.addItem(c, 1)),
          ),
        );
      },
    );
  }
}
