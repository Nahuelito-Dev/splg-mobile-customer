import 'package:flutter/material.dart';
import 'package:splg_customer/ui/views/order_detail/widgets/transfer_card.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'order_tracking_viewmodel.dart';
import 'widgets/arriving_banner.dart';

/// Seguimiento del pedido con la distribución de la referencia de diseño: mapa
/// a pantalla completa con el estado arriba y, abajo, la hoja con el
/// repartidor, la llegada estimada y las acciones.
class OrderTrackingView extends StackedView<OrderTrackingViewModel> {
  const OrderTrackingView({
    super.key,
    required this.orderId,
  });

  final String orderId;

  /// Sólo para tests: reemplaza el mapa de Google por un placeholder.
  @visibleForTesting
  static Widget Function(BuildContext, OrderTrackingViewModel)? debugMapBuilder;

  /// Sólo para tests: fabrica el ViewModel.
  @visibleForTesting
  static OrderTrackingViewModel Function(String)? debugViewModelFactory;

  @override
  Widget builder(
    BuildContext context,
    OrderTrackingViewModel viewModel,
    Widget? child,
  ) {
    if (!viewModel.hasOrderLoaded) {
      return Scaffold(
        body: viewModel.isBusy
            ? const SplgLoader()
            : _LoadError(model: viewModel),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: OrderTrackingView.debugMapBuilder?.call(
                  context,
                  viewModel,
                ) ??
                _TrackingMap(model: viewModel),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _StatusCard(model: viewModel),
            ),
          ),
          if (viewModel.showArrivingBanner)
            const SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 132),
                  child: ArrivingBanner(),
                ),
              ),
            ),
          if (!viewModel.isFinished)
            Positioned(
              left: 8,
              bottom: context.sp(210),
              child: SplgFloatingButton(
                key: const Key('tracking-locate'),
                tooltip: 'Recentrar',
                icon: SplgIcons.locate,
                onPressed: viewModel.recenterMap,
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _TrackingSheet(model: viewModel),
          ),
        ],
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
      debugViewModelFactory?.call(orderId) ??
      OrderTrackingViewModel(orderId: orderId);
}

/// Mapa con la dirección de entrega, la ruta y la camioneta del repartidor.
class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    Widget map(Set<Marker> markers) => GoogleMap(
          mapType: MapType.terrain,
          initialCameraPosition: CameraPosition(
            target: model.fallbackCenter,
            zoom: 14,
          ),
          onMapCreated: model.onMapCreated,
          onCameraMoveStarted: model.onMapMovedByUser,
          markers: markers,
          polylines: model.polylines,
          circles: model.circles,
          // Deja libre el centro: la dirección y la ruta no quedan tapadas
          // por la tarjeta de arriba ni por la hoja de abajo.
          padding: const EdgeInsets.only(top: 140, bottom: 320),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
        );

    final position = model.driverPosition;
    if (position == null || model.isFinished) return map(model.markers);
    return SplgAnimatedVehicle(
      position: position,
      heading: model.driverHeading,
      icon: model.vehicleIcon,
      builder: (_, vehicle) => map({...model.markers, vehicle}),
    );
  }
}

/// Tarjeta superior: volver, número de pedido, ayuda y la píldora de estado.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final (icon, text) = switch (model.stage) {
      TrackingStage.pending => (SplgIcons.clock, 'Buscando repartidor'),
      TrackingStage.assigned => (SplgIcons.ok, 'Pedido asignado'),
      TrackingStage.inProgress => (SplgIcons.truck, 'En camino'),
      TrackingStage.arriving => (SplgIcons.house, 'Llegando'),
      TrackingStage.delivered => (SplgIcons.ok, 'Entregado'),
      TrackingStage.cancelled => (SplgIcons.close, 'Cancelado'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SplgIconButton(
          key: const Key('tracking-back'),
          tooltip: 'Volver',
          icon: SplgIcons.back,
          size: 44,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SplgDarkCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.orderTitle,
                  key: const Key('tracking-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.subtitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  key: const Key('tracking-status-pill'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.body.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SplgIconButton(
          key: const Key('tracking-help'),
          tooltip: 'Ayuda',
          icon: SplgIcons.help,
          size: 44,
          onPressed: model.showHelp,
        ),
      ],
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  const _TrackingSheet({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return SplgBottomPanel(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: model.isFinished
              ? _FinishedContent(model: model)
              : _ActiveContent(model: model),
        ),
      ),
    );
  }
}

/// Pedido en curso: avance, llegada estimada, repartidor y acciones.
class _ActiveContent extends StatelessWidget {
  const _ActiveContent({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrackingStepper(activeStep: model.currentStepIndex),
        const SizedBox(height: 12),
        Text(
          model.statusTitle,
          key: const Key('tracking-status-title'),
          style: type.subtitle,
        ),
        if (model.expressNotice != null) ...[
          const SizedBox(height: 6),
          Text(model.expressNotice!,
              key: const Key('tracking-express-notice'), style: type.caption),
        ],
        if (model.showDriverCard || model.stage == TrackingStage.pending) ...[
          const SizedBox(height: 4),
          Text(model.etaTitle,
              key: const Key('tracking-eta'), style: type.heading),
          Text(model.etaSubtitle, style: type.caption),
        ],
        if (model.showDriverCard) ...[
          const SizedBox(height: 12),
          _DriverCard(model: model),
        ],
        if (model.canConfirmDelivery) ...[
          const SizedBox(height: 12),
          SplgButton(
            key: const Key('tracking-confirm-qr'),
            title: 'Confirmar entrega (escanear QR)',
            onPressed: model.confirmDeliveryByScan,
          ),
          const SizedBox(height: 8),
          SplgButton(
            key: const Key('tracking-confirm-code'),
            title: 'Ingresar el código',
            style: SplgButtonStyle.outlined,
            onPressed: model.confirmDeliveryByCode,
          ),
        ],
        if (model.showTransferCard) ...[
          const SizedBox(height: 16),
          TransferCard(model: model),
        ],
        const SizedBox(height: 12),
        Text(model.compactOrderDetail, style: type.body),
        if (model.expandedOrderDetail.isNotEmpty)
          SplgAccordion(
            entries: [
              SplgAccordionEntry(
                title: 'Ver detalle',
                body: model.expandedOrderDetail.join('\n'),
              ),
            ],
          ),
        if (model.canCancelOrder) ...[
          const SizedBox(height: 6),
          SplgButton(
            key: const Key('tracking-cancel'),
            title: 'Cancelar pedido',
            style: SplgButtonStyle.danger,
            onPressed: model.isBusy ? null : model.cancelOrder,
          ),
        ],
      ],
    );
  }
}

/// Pedido entregado o cancelado: ya no hay nada que seguir.
class _FinishedContent extends StatelessWidget {
  const _FinishedContent({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final delivered = model.isDelivered;
    final detail = model.finishedDetail;
    return Column(
      children: [
        Icon(
          delivered ? SplgIcons.ok : SplgIcons.error,
          size: 44,
          color: delivered ? brasa.success : brasa.danger,
        ),
        const SizedBox(height: 8),
        Text(
          model.statusTitle,
          key: const Key('tracking-finished-title'),
          textAlign: TextAlign.center,
          style: type.heading,
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            key: const Key('tracking-finished-detail'),
            textAlign: TextAlign.center,
            style: type.body,
          ),
        ],
        const SizedBox(height: 16),
        if (delivered) ...[
          SplgButton(
            key: const Key('tracking-rate'),
            title: 'Calificar al repartidor',
            onPressed: model.rateDriver,
          ),
          const SizedBox(height: 10),
        ],
        SplgButton(
          key: const Key('tracking-close'),
          title: 'Volver',
          style: SplgButtonStyle.outlined,
          onPressed: model.close,
        ),
      ],
    );
  }
}

class _TrackingStepper extends StatelessWidget {
  const _TrackingStepper({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    const steps = [
      (icon: SplgIcons.clock, label: 'Pendiente'),
      (icon: SplgIcons.ok, label: 'Asignado'),
      (icon: SplgIcons.truck, label: 'En camino'),
      (icon: SplgIcons.house, label: 'Llegando'),
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
                  color: active ? brasa.primaryStrong : brasa.outline,
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final active = stepIndex <= activeStep;
            return Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: active ? brasa.primaryStrong : brasa.outline,
                shape: BoxShape.circle,
              ),
              child: Icon(steps[stepIndex].icon, size: 16, color: Colors.white),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final step in steps)
              Expanded(
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: type.caption,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final rating = model.driverRating;
    final plate = model.vehiclePlate;
    return Column(
      children: [
        Row(
          children: [
            SplgAvatar(
              imageUrl: model.driverAvatarUrl,
              initials: model.driverInitials,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.driverName,
                    key: const Key('tracking-driver-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.subtitle,
                  ),
                  Row(
                    children: [
                      Icon(
                        rating == null ? SplgIcons.starEmpty : SplgIcons.star,
                        size: 13,
                        color: brasa.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating == null
                            ? 'Sin calificaciones'
                            : rating.toStringAsFixed(1),
                        key: const Key('tracking-driver-rating'),
                        style: type.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (plate != null)
              Container(
                key: const Key('tracking-plate'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: brasa.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(plate, style: type.value),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SplgRouteRow(
          icon: SplgIcons.truck,
          text: model.vehicleName ?? 'Vehículo sin datos',
          color: brasa.primaryStrong,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SplgButton(
                key: const Key('tracking-call'),
                title: 'Llamar',
                style: SplgButtonStyle.outlined,
                onPressed: model.hasDriverPhone ? model.callDriver : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SplgButton(
                key: const Key('tracking-message'),
                title: 'Escribirle',
                style: SplgButtonStyle.outlined,
                onPressed: model.hasDriverPhone ? model.messageDriver : null,
              ),
            ),
          ],
        ),
        if (model.contactHint != null) ...[
          const SizedBox(height: 6),
          Text(
            model.contactHint!,
            key: const Key('tracking-contact-hint'),
            textAlign: TextAlign.center,
            style: type.caption,
          ),
        ],
      ],
    );
  }
}

/// El pedido no se pudo cargar: texto claro y "Reintentar".
class _LoadError extends StatelessWidget {
  const _LoadError({required this.model});

  final OrderTrackingViewModel model;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SplgEmptyState(
        illustration: SplgIllustration.error,
        title: 'No pudimos cargar',
        message: model.loadError ?? 'No pudimos cargar tu pedido.',
        action: model.canRetryLoad
            ? SplgButton(
                key: const Key('tracking-retry'),
                title: 'Reintentar',
                style: SplgButtonStyle.outlined,
                expand: false,
                onPressed: model.retry,
              )
            : SplgButton(
                key: const Key('tracking-back'),
                title: 'Volver',
                style: SplgButtonStyle.outlined,
                expand: false,
                onPressed: model.close,
              ),
      ),
    );
  }
}
