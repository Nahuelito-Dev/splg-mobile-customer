import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';

import 'order_tracking_viewmodel.dart';

class OrderTrackingView extends StackedView<OrderTrackingViewModel> {
  const OrderTrackingView({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  Widget builder(
    BuildContext context,
    OrderTrackingViewModel viewModel,
    Widget? child,
  ) {
    final theme = Theme.of(context);

    if (viewModel.isBusy && !viewModel.hasOrderLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sheetHeight = constraints.maxHeight * 0.40;

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: viewModel.fallbackCenter,
                  zoom: 14,
                ),
                onMapCreated: viewModel.onMapCreated,
                onCameraMoveStarted: viewModel.onMapMovedByUser,
                markers: viewModel.markers,
                polylines: viewModel.polylines,
                circles: viewModel.circles,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          viewModel.orderTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _HeaderIconButton(
                        icon: Icons.help_outline,
                        onTap: viewModel.showHelp,
                      ),
                    ],
                  ),
                ),
              ),
              if (viewModel.showArrivingBanner)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 76),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'Tu garrafa esta llegando! Por favor sali a recibirla.',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: sheetHeight + 20,
                child: FloatingActionButton.small(
                  heroTag: 'recenter_map',
                  onPressed: viewModel.recenterMap,
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.my_location),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: sheetHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 14,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TrackingStepper(
                          activeStep: viewModel.currentStepIndex,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          viewModel.statusTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          viewModel.etaTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          viewModel.etaSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(170),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (viewModel.showDriverCard)
                          _DriverCard(viewModel: viewModel),
                        if (!viewModel.showDriverCard)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Buscando al repartidor mas cercano...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (viewModel.canConfirmDelivery) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: viewModel.confirmDeliveryByScan,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text(
                                'Confirmar entrega (escanear QR)',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          viewModel.compactOrderDetail,
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: viewModel.toggleOrderDetails,
                          child: Text(
                            viewModel.detailsExpanded
                                ? 'Ocultar detalle'
                                : 'Ver detalle',
                          ),
                        ),
                        if (viewModel.detailsExpanded)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withAlpha(90),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: viewModel.expandedOrderDetail
                                  .map(
                                    (line) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6.0),
                                      child: Text(line),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (viewModel.canCancelOrder) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: viewModel.cancelOrder,
                              icon: const Icon(Icons.close),
                              label: const Text('Cancelar pedido'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void onViewModelReady(OrderTrackingViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }

  @override
  OrderTrackingViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      OrderTrackingViewModel(orderId: orderId);
}

class _TrackingStepper extends StatelessWidget {
  const _TrackingStepper({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = [
      (icon: Icons.schedule, label: 'Pendiente'),
      (icon: Icons.check_circle, label: 'Asignado'),
      (icon: Icons.local_shipping, label: 'En camino'),
      (icon: Icons.home, label: 'Llegando'),
    ];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final connectorIndex = (index ~/ 2) + 1;
              final active = connectorIndex <= activeStep;
              return Expanded(
                child: Container(
                  height: 2,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final active = stepIndex <= activeStep;
            return Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                steps[stepIndex].icon,
                size: 15,
                color: Colors.white,
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          children: steps
              .map(
                (step) => Expanded(
                  child: Text(
                    step.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.viewModel});

  final OrderTrackingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withAlpha(90),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withAlpha(30),
                backgroundImage: (viewModel.driverAvatarUrl != null &&
                        viewModel.driverAvatarUrl!.isNotEmpty)
                    ? NetworkImage(viewModel.driverAvatarUrl!)
                    : null,
                child: (viewModel.driverAvatarUrl == null ||
                        viewModel.driverAvatarUrl!.isEmpty)
                    ? Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.driverName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '⭐ ${viewModel.driverRatingText}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  viewModel.vehiclePlate,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.vehicleName,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: viewModel.callDriver,
                  icon: const Icon(Icons.phone),
                  label: const Text('Llamar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: viewModel.messageDriver,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Mensaje'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(100),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
