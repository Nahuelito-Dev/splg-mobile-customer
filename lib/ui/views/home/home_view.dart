import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/app_drawer/app_drawer.dart';
import 'home_viewmodel.dart';
import 'widgets/catalog_sheet.dart';
import 'widgets/home_map.dart';

class HomeView extends StackedView<HomeViewModel> {
  const HomeView({super.key});

  @override
  void onViewModelReady(HomeViewModel viewModel) => viewModel.initialize();

  @override
  HomeViewModel viewModelBuilder(BuildContext context) => HomeViewModel();

  @override
  Widget builder(BuildContext context, HomeViewModel model, Widget? child) {
    final brasa = context.brasa;
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: brasa.surfaceSunken,
      body: Stack(
        children: [
          Positioned.fill(
            child: HomeMap(
              delivery: model.deliveryPoint,
              user: model.userPoint,
              showUserLocation: model.showUserLocation,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (ctx) => SplgIconButton(
                    icon: SplgIcons.menu,
                    tooltip: 'Abrir menú',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (model.locationNotice != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _LocationNotice(
                      text: model.locationNotice!,
                      onSettings: model.openLocationSettings,
                      onClose: model.dismissLocationNotice,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SplgIconButton(
                      icon: SplgIcons.locate,
                      tooltip: 'Mi ubicación',
                      size: 48,
                      onPressed: model.locateMe,
                    ),
                  ),
                ),
                if (model.hasActiveOrder)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _ActiveOrderBanner(
                      code: model.activeOrderShortCode,
                      status: model.activeOrderStatusLabel,
                      onTap: model.openActiveOrder,
                    ),
                  ),
                SplgBottomPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SplgAddressPill(
                        text: model.deliveryLabel,
                        onTap: model.chooseAddress,
                      ),
                      if (model.addressNotice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(model.addressNotice!,
                              key: const Key('home-address-notice'),
                              textAlign: TextAlign.center,
                              style: SplgType.of(context)
                                  .caption
                                  .copyWith(color: brasa.danger)),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CatalogField(
                              onTap: () {
                                if (model.loadError != null) {
                                  model.reloadCatalog();
                                }
                                showCatalogSheet(context, model);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SplgIconButton(
                            icon: SplgIcons.plus,
                            tooltip: 'Agregar dirección',
                            size: 52,
                            onPressed: model.addAddress,
                          ),
                        ],
                      ),
                      if (model.canPlaceOrder) ...[
                        const SizedBox(height: 12),
                        SplgButton(
                          title: model.continueLabel,
                          onPressed: model.placeOrder,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de "Mi ubicación" (GPS apagado) con camino a Ajustes.
class _LocationNotice extends StatelessWidget {
  const _LocationNotice(
      {required this.text, required this.onSettings, required this.onClose});

  final String text;
  final VoidCallback onSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('home-location-notice'),
      color: scheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(
          children: [
            Expanded(child: Text(text, style: type.body)),
            TextButton(onPressed: onSettings, child: const Text('Ajustes')),
            IconButton(
              tooltip: 'Cerrar aviso',
              icon: const Icon(SplgIcons.close, size: 18),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de búsqueda del catálogo: no se escribe, abre la hoja de garrafas.
class _CatalogField extends StatelessWidget {
  const _CatalogField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brasa = context.brasa;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-catalog-field'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: brasa.primaryStrong, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(SplgIcons.search, color: brasa.primaryStrong, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('¿Qué necesitás?',
                    style: SplgType.of(context)
                        .body
                        .copyWith(color: brasa.primaryStrong)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pedido en curso: estado y acceso al seguimiento.
class _ActiveOrderBanner extends StatelessWidget {
  const _ActiveOrderBanner(
      {required this.code, required this.status, required this.onTap});

  final String code;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: SplgGradients.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(SplgIcons.truck, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pedido en curso #$code',
                          style: type.value.copyWith(color: Colors.white)),
                      Text(status,
                          style: type.caption.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                Text('Ver', style: type.value.copyWith(color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(SplgIcons.next, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
