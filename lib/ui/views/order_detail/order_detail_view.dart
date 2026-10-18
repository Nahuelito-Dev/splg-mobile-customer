import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/pricing.dart';
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
    final brasa = context.brasa;
    return LoadScaffold(
      title: 'Mi pedido',
      model: model,
      builder: (context) {
        final o = model.order!;
        final street = o.address?.streetName.trim() ?? '';
        final actions = <Widget>[
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
                  trailing: statusLabel(o.status)),
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
                    const SizedBox(height: 16),
                    SplgInfoSection(
                      icon: SplgIcons.cart,
                      title: 'Tu pedido',
                      rows: [
                        for (final i in o.items)
                          SplgInfoRow(
                              title: itemLabel(i),
                              value: money.format(Pricing.subtotal(i))),
                        if ((model.breakdown?.zoneSurcharge ?? 0) > 0)
                          SplgInfoRow(
                              title: 'Recargo por zona',
                              value:
                                  money.format(model.breakdown!.zoneSurcharge)),
                        if ((model.breakdown?.expressSurchargeInTotal ?? 0) > 0)
                          SplgInfoRow(
                              title: 'Recargo express',
                              value: money.format(
                                  model.breakdown!.expressSurchargeInTotal)),
                        if ((model.breakdown?.paymentSurcharge ?? 0) > 0)
                          SplgInfoRow(
                              title: 'Recargo por medio de pago',
                              value: money
                                  .format(model.breakdown!.paymentSurcharge)),
                      ],
                    ),
                    SplgInfoSection(
                      icon: SplgIcons.location,
                      title: 'Entrega',
                      rows: [
                        SplgInfoRow(
                            title: 'Dirección:',
                            value: street.isEmpty ? null : street),
                        if (o.address?.city != null)
                          SplgInfoRow(
                              title: 'Localidad:', value: o.address!.city),
                        if (o.deliveryWindowStart != null)
                          SplgInfoRow(
                              title: 'Franja:',
                              value:
                                  '${hhmm(o.deliveryWindowStart!)} – ${hhmm(o.deliveryWindowEnd ?? '')}'),
                        if ((o.customerNotes ?? '').isNotEmpty)
                          SplgInfoRow(title: 'Notas:', value: o.customerNotes),
                        if (model.isExpress)
                          const SplgInfoRow(
                              title: 'Modalidad:', value: 'Express'),
                        if (model.receiver != null)
                          SplgInfoRow(
                              title: 'Recibe:',
                              value:
                                  '${model.receiver!.name} (${model.receiver!.relationship}) · Doc. ${model.receiver!.document}'),
                      ],
                    ),
                    if (model.refundRows.isNotEmpty)
                      SplgInfoSection(
                        key: const Key('detail-refunds'),
                        icon: SplgIcons.cash,
                        title: 'Devolución del pago',
                        rows: [
                          for (final r in model.refundRows)
                            SplgInfoRow(title: r.title, value: r.value),
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
                      SplgInfoSection(
                        icon: SplgIcons.truck,
                        title: 'Repartidor',
                        rows: [
                          SplgInfoRow(title: 'Nombre:', value: o.deliveryName)
                        ],
                      ),
                    const SizedBox(height: 8),
                    Divider(color: brasa.outline),
                    const SizedBox(height: 8),
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
