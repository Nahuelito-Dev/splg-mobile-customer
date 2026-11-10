import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/views/order_detail/widgets/transfer_card.dart';
import 'package:splg_customer/ui/widgets/app_info.dart';

import 'package:splg_customer/services/order_document_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'order_detail_viewmodel.dart';

class OrderDetailView extends StackedView<OrderDetailViewModel> {
  const OrderDetailView({super.key, required this.orderId, this.order});

  final String orderId;

  /// El pedido tal como lo trae la lista (se ve mientras se refresca).
  final Order? order;

  @override
  OrderDetailViewModel viewModelBuilder(BuildContext context) =>
      OrderDetailViewModel(orderId: orderId, initial: order);

  @override
  void onViewModelReady(OrderDetailViewModel viewModel) => viewModel.load();

  @override
  Widget builder(
      BuildContext context, OrderDetailViewModel model, Widget? child) {
    final type = SplgType.of(context);
    return LoadScaffold(
      title: 'Mi pedido',
      model: model,
      builder: (context) {
        final o = model.order!;
        final street = o.address?.streetName.trim() ?? '';
        final actions = <Widget>[
          if (model.canPayDeposit)
            SplgButton(
                key: const Key('detail-pay-deposit'),
                title: 'Pagar la seña',
                loading: model.payingDeposit,
                onPressed: model.payingDeposit ? null : model.payDeposit),
          if (model.canTrack)
            SplgButton(title: 'Ver seguimiento', onPressed: model.track),
          if (model.canRate)
            SplgButton(title: 'Calificar al repartidor', onPressed: model.rate),
          if (model.canModify)
            SplgButton(
                title: 'Modificar pedido',
                style: SplgButtonStyle.outlined,
                onPressed: model.modify),
          if (model.canChangeAddress)
            SplgButton(
                key: const Key('detail-change-address'),
                title: 'Cambiar dirección de entrega',
                style: SplgButtonStyle.outlined,
                onPressed: model.changeAddress),
          if (model.canSetReceiver)
            SplgButton(
                key: const Key('detail-receiver'),
                title: model.receiver == null
                    ? 'Indicar quién recibe'
                    : 'Cambiar quién recibe',
                style: SplgButtonStyle.outlined,
                onPressed: model.editReceiver),
          if (model.canDownloadRemito)
            SplgButton(
                key: const Key('detail-remito'),
                title: 'Remito (PDF)',
                style: SplgButtonStyle.outlined,
                loading: model.downloading == OrderDocument.remito,
                onPressed: model.downloading == null
                    ? () => model.openDocument(OrderDocument.remito)
                    : null),
          if (model.canDownloadRecibo)
            SplgButton(
                key: const Key('detail-recibo'),
                title: 'Recibo (PDF)',
                style: SplgButtonStyle.outlined,
                loading: model.downloading == OrderDocument.recibo,
                onPressed: model.downloading == null
                    ? () => model.openDocument(OrderDocument.recibo)
                    : null),
          if (model.canRepeat)
            SplgButton(
                title: 'Repetir pedido',
                style: SplgButtonStyle.outlined,
                onPressed: model.repeat),
          if (model.canClaim)
            SplgButton(
                title: 'Hacer un reclamo',
                style: SplgButtonStyle.outlined,
                onPressed: model.claim),
          if (model.canCancel)
            SplgButton(
                title: 'Cancelar pedido',
                style: SplgButtonStyle.danger,
                onPressed: model.cancel),
        ];
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SplgSectionBar(
                  title: dateTimeLabel(o.createdAt),
                  trailing: orderStatusLabel(o)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SplgSoftCard(
                      label: 'Total del pedido',
                      amount: money.format(o.total),
                      caption:
                          'Forma de pago: ${paymentLabel(o.paymentMethod)}',
                      amountKey: const Key('detail-total'),
                    ),
                    if (model.liveNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(model.liveNotice!,
                            key: const Key('detail-live-notice'),
                            style: type.caption
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 16),
                    if (model.reservationRows.isNotEmpty) ...[
                      AppInfoSection(
                        key: const Key('detail-reservation'),
                        icon: SplgIcons.calendar,
                        title: 'Reserva con seña',
                        rows: [
                          for (final r in model.reservationRows)
                            AppInfoRow(title: r.title, value: r.value),
                        ],
                      ),
                      if (model.isReserved)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                              'Tu reserva se activa y sale a reparto el día de '
                              'la entrega, si la seña está paga.',
                              key: const Key('detail-reservation-note'),
                              style: type.caption),
                        ),
                    ],
                    if (model.showTransferCard) TransferCard(model: model),
                    AppInfoSection(
                      icon: SplgIcons.cart,
                      title: 'Tu pedido',
                      rows: [
                        for (final i in o.items)
                          AppInfoRow(
                              title: itemLabel(i),
                              value: i.subtotal == null
                                  ? ''
                                  : money.format(i.subtotal!)),
                        if (model.chargesContainers)
                          AppInfoRow(
                              key: const Key('detail-container-charge'),
                              title: containerChargeLabel(
                                  model.breakdown!.containersCharged),
                              value: money.format(
                                  model.breakdown!.containerChargeAmount)),
                        if ((model.breakdown?.zoneSurcharge ?? 0) > 0)
                          AppInfoRow(
                              title: 'Recargo por zona',
                              value:
                                  money.format(model.breakdown!.zoneSurcharge)),
                        if ((model.breakdown?.expressSurchargeInTotal ?? 0) > 0)
                          AppInfoRow(
                              title: 'Recargo express',
                              value: money.format(
                                  model.breakdown!.expressSurchargeInTotal)),
                        if ((model.breakdown?.paymentSurcharge ?? 0) > 0)
                          AppInfoRow(
                              title:
                                  model.breakdown!.paymentSurchargePercentage ==
                                          null
                                      ? 'Recargo por pago'
                                      : paymentSurchargeLabel(
                                          switch (o.paymentMethod) {
                                            PaymentMethod.cash => 'cash',
                                            PaymentMethod.online => 'transfer',
                                            PaymentMethod.mercadoPago =>
                                              'mercadopago',
                                          },
                                          model.breakdown!
                                              .paymentSurchargePercentage),
                              value: money
                                  .format(model.breakdown!.paymentSurcharge)),
                      ],
                    ),
                    AppInfoSection(
                      icon: SplgIcons.location,
                      title: 'Entrega',
                      rows: [
                        AppInfoRow(
                            title: 'Dirección:',
                            value: street.isEmpty ? null : street),
                        if (o.address?.city != null)
                          AppInfoRow(
                              title: 'Localidad:', value: o.address!.city),
                        if (o.deliveryWindowStart != null)
                          AppInfoRow(
                              title: 'Franja:',
                              value:
                                  '${hhmm(o.deliveryWindowStart!)} – ${hhmm(o.deliveryWindowEnd ?? '')}'),
                        if ((o.customerNotes ?? '').isNotEmpty)
                          AppInfoRow(title: 'Notas:', value: o.customerNotes),
                        if (model.isExpress)
                          const AppInfoRow(
                              title: 'Modalidad:', value: 'Express'),
                        if (model.receiver != null)
                          AppInfoRow(
                              title: 'Recibe:',
                              value:
                                  '${model.receiver!.name} (${model.receiver!.relationship}) · Doc. ${model.receiver!.document}'),
                      ],
                    ),
                    if (model.refundRows.isNotEmpty)
                      AppInfoSection(
                        key: const Key('detail-refunds'),
                        icon: SplgIcons.cash,
                        title: 'Devolución del pago',
                        rows: [
                          for (final r in model.refundRows)
                            AppInfoRow(title: r.title, value: r.value),
                        ],
                      ),
                    if (model.expressDegraded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            'Ningún repartidor en moto aceptó tu pedido express: '
                            'pasó al reparto común y se descontó el recargo '
                            'express${(model.breakdown?.expressSurchargeAmount ?? 0) > 0 ? ' (${money.format(model.breakdown!.expressSurchargeAmount)})' : ''}.'
                            '${model.paidOnline ? ' Como lo pagaste en línea, el recargo se te devuelve.' : ''}',
                            key: const Key('detail-express-degraded'),
                            style: type.caption),
                      ),
                    if (o.deliveryName != null)
                      AppInfoSection(
                        icon: SplgIcons.truck,
                        title: 'Repartidor',
                        rows: [
                          AppInfoRow(title: 'Nombre:', value: o.deliveryName),
                          if (model.driverSummary != null)
                            AppInfoRow(
                                key: const Key('detail-driver-rating'),
                                title: 'Calificación:',
                                value: model.driverSummary!.label)
                        ],
                      ),
                    if (model.historyError != null ||
                        model.driverSummaryError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (model.historyError != null)
                              Text(
                                  'No pudimos cargar el historial del pedido. '
                                  '${model.historyError}',
                                  key: const Key('detail-timeline-error'),
                                  style: type.caption),
                            if (model.driverSummaryError != null)
                              Text(
                                  'No pudimos cargar la calificación del '
                                  'repartidor. ${model.driverSummaryError}',
                                  key: const Key('detail-driver-rating-error'),
                                  style: type.caption),
                            SplgButton(
                                key: const Key('detail-extras-retry'),
                                title: 'Reintentar',
                                style: SplgButtonStyle.outlined,
                                loading: model.retryingExtras,
                                onPressed: model.retryingExtras
                                    ? null
                                    : model.retryExtras),
                          ],
                        ),
                      ),
                    if (model.timelineRows.isNotEmpty)
                      AppInfoSection(
                        key: const Key('detail-timeline'),
                        icon: SplgIcons.clock,
                        title: 'Historial del pedido',
                        rows: [
                          for (final r in model.timelineRows)
                            AppInfoRow(title: r.title, value: r.value),
                        ],
                      ),
                    const SizedBox(height: 4),
                    for (final a in actions)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10), child: a),
                    if (actions.isEmpty)
                      Text('Este pedido no tiene acciones disponibles.',
                          style: type.caption),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
