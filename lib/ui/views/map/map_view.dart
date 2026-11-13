import 'package:flutter/material.dart';
import 'package:splg_lib/icons/splg_icons.dart';
import 'package:splg_lib/theme/brasa_palette.dart';
import 'package:stacked/stacked.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:splg_customer/core/config/app_config.dart';

import 'map_viewmodel.dart';

class MapView extends StackedView<MapViewModel> {
  const MapView({super.key});

  @override
  Widget builder(
    BuildContext context,
    MapViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: viewModel.currentPosition ??
                        LatLng(
                            AppConfig.mapFallbackLat, AppConfig.mapFallbackLng),
                    zoom: 15,
                  ),
                  onMapCreated: viewModel.onMapCreated,
                  onCameraIdle: viewModel.onCameraIdle,
                  // Sólo se activa con el permiso concedido: así el SDK del mapa
                  // no dispara su propio pedido sin explicación.
                  myLocationEnabled: viewModel.hasLocation,
                  myLocationButtonEnabled: viewModel.hasLocation,
                ),
                if (viewModel.locationNotice != null)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _LocationNotice(viewModel: viewModel),
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Icon(
                      SplgIcons.location,
                      color: Theme.of(context).colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ubicación seleccionada',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          viewModel.currentAddress != null
                              ? '${viewModel.currentAddress!.street}, ${viewModel.currentAddress!.locality}'
                              : 'Buscando dirección...',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: viewModel.isBusy
                              ? null
                              : viewModel.confirmLocation,
                          child: viewModel.isBusy
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : Text('Confirmar Ubicación',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontWeight: FontWeight.bold,
                                      )),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void onViewModelReady(MapViewModel viewModel) {
    viewModel.initialize();
  }

  @override
  MapViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      MapViewModel();
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.viewModel});

  final MapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = context.brasa;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: palette.warnSoft,
        border: Border.all(color: palette.warn),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              viewModel.locationNotice!,
              style:
                  TextStyle(color: palette.warn, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: viewModel.canOpenSettings
                ? viewModel.openSettings
                : viewModel.retryLocation,
            child: Text(viewModel.canOpenSettings ? 'Ajustes' : 'Reintentar'),
          ),
        ],
      ),
    );
  }
}
