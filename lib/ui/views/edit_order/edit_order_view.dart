import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'edit_order_viewmodel.dart';

/// Modificar un pedido pendiente: mismo diseño que la confirmación (dirección,
/// total, forma de pago, cuándo y franja, notas) más las cantidades de cada
/// garrafa, sobre el degradé de marca.
class EditOrderView extends StackedView<EditOrderViewModel> {
  const EditOrderView({super.key, required this.order, this.breakdown});

  /// El pedido que se modifica.
  final Order order;

  /// Desglose y cobro del pedido, si ya se leyó.
  final OrderBreakdown? breakdown;

  @override
  EditOrderViewModel viewModelBuilder(BuildContext context) =>
      EditOrderViewModel(original: order, breakdown: breakdown);

  @override
  void onViewModelReady(EditOrderViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }

  @override
  Widget builder(
    BuildContext context,
    EditOrderViewModel model,
    Widget? child,
  ) {
    final type = SplgType.of(context);
    final white = type.body.copyWith(color: Colors.white);

    Widget divider() => const Divider(color: Colors.white24, height: 1);

    Widget body() {
      if (model.loading) {
        return const Center(child: SplgLoader(onDark: true));
      }
      if (model.loadError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(model.loadError!,
                    key: const Key('edit-load-error'),
                    textAlign: TextAlign.center,
                    style: white),
                const SizedBox(height: 16),
                SplgButton(
                  title: 'Reintentar',
                  style: SplgButtonStyle.white,
                  expand: false,
                  onPressed: model.initialize,
                ),
              ],
            ),
          ),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SplgAddressPill(
              key: const Key('edit-address'),
              text: model.address?.streetName.isNotEmpty == true
                  ? model.address!.streetName
                  : 'Elegí tu dirección de entrega',
              onDark: true,
              onTap: model.showAddressList,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final c in model.cylinders)
                    _ItemRow(model: model, cylinder: c),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total',
                          style: type.caption.copyWith(color: Colors.white70)),
                      Text(
                          model.quote == null
                              ? '—'
                              : money.format(model.quote!.total),
                          key: const Key('edit-total'),
                          style: type.amount.copyWith(color: Colors.white)),
                    ],
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (model.quoting)
                          Text('Calculando…',
                              key: const Key('edit-quoting'),
                              style:
                                  type.caption.copyWith(color: Colors.white70)),
                        if ((model.quote?.zoneSurcharge ?? 0) > 0)
                          Text(
                              'Recargo por zona ${money.format(model.quote!.zoneSurcharge)}',
                              key: const Key('edit-zone-surcharge'),
                              textAlign: TextAlign.right,
                              style:
                                  type.caption.copyWith(color: Colors.white70)),
                        if ((model.quote?.paymentSurcharge ?? 0) > 0)
                          Text(
                              '${paymentSurchargeLabel(model.quote!.paymentMethod, model.quote!.paymentSurchargePercentage)} ${money.format(model.quote!.paymentSurcharge)}',
                              key: const Key('edit-payment-surcharge'),
                              textAlign: TextAlign.right,
                              style:
                                  type.caption.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (model.quoteError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: GestureDetector(
                  key: const Key('edit-quote-error'),
                  onTap: model.canRetryQuote ? model.retryQuote : null,
                  child: Text(
                    model.canRetryQuote
                        ? '${model.quoteError} Tocá para reintentar.'
                        : model.quoteError!,
                    style: type.caption.copyWith(color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            divider(),
            SplgOptionRow(
              key: const Key('edit-payment'),
              onDark: true,
              dropdown: true,
              icon: SplgIcons.cash,
              title: 'Forma de pago',
              value: paymentLabel(model.paymentMethod),
              onTap: model.togglePayment,
            ),
            if (model.paymentOpen)
              for (final m in kEditablePaymentMethods)
                SplgRadioRow(
                  key: Key('edit-pay-${m.name}'),
                  onDark: true,
                  title: paymentLabel(m),
                  selected: model.paymentMethod == m,
                  onTap: () => model.setPaymentMethod(m),
                ),
            divider(),
            SplgOptionRow(
              key: const Key('edit-date'),
              onDark: true,
              icon: SplgIcons.calendar,
              title: 'Fecha de entrega',
              value: model.formattedDate,
              onTap: () => model.selectDate(context),
            ),
            divider(),
            SplgOptionRow(
              key: const Key('edit-slots'),
              onDark: true,
              dropdown: true,
              icon: SplgIcons.clock,
              title: 'Franja de entrega',
              value: model.selectedSlotLabel ?? 'Elegí una',
              onTap: model.toggleSlots,
            ),
            if (model.slotsOpen)
              if (model.loadingTimeSlots)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SplgLoader(onDark: true),
                )
              else if (model.timeSlots.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      'No hay franjas disponibles para esta fecha. '
                      'Probá con otro día.',
                      style: white),
                )
              else
                for (final slot in model.timeSlots)
                  SplgRadioRow(
                    key: Key('edit-slot-${slot.timeSlotId}'),
                    onDark: true,
                    title: slot.label,
                    subtitle: model.canPickSlot(slot)
                        ? 'Quedan ${slot.remaining}'
                        : 'Sin cupo',
                    selected: slot.timeSlotId == model.selectedTimeSlotId,
                    onTap: model.canPickSlot(slot)
                        ? () => model.selectTimeSlot(slot.timeSlotId)
                        : null,
                  ),
            divider(),
            const SizedBox(height: 12),
            Text('Detalles de la entrega (opcional)',
                style: type.caption.copyWith(color: Colors.white70)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SplgTextArea(
                controller: model.notesController,
                hint: 'Ej: tocar timbre, dejar en portería…',
                maxLength: 300,
                minLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const SplgHeader(title: 'Modificar pedido', onGradient: true),
      body: SplgGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: body()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SplgButton(
                      title: 'Guardar cambios',
                      style: SplgButtonStyle.white,
                      loading: model.saving,
                      onPressed: model.canSave ? model.save : null,
                    ),
                    const SizedBox(height: 10),
                    SplgButton(
                      title: 'Cancelar',
                      style: SplgButtonStyle.ghost,
                      onPressed: model.saving
                          ? null
                          : () => Navigator.of(context).pop(),
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

/// Renglón de una garrafa: nombre, precio (con la promoción que aplicó el back)
/// y el selector de cantidad.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.model, required this.cylinder});

  final EditOrderViewModel model;
  final GasCylinder cylinder;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final qty = model.quantityOf(cylinder.id);
    final line = model.quoteLineFor(cylinder.id);
    final promos = Pricing.sortedDiscounts(cylinder);
    return Padding(
      key: Key('edit-item-${cylinder.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cylinder.label, style: type.subtitle),
                Text(
                    qty > 0 && line != null
                        ? money.format(line.subtotal)
                        : money.format(cylinder.price),
                    key: Key('edit-item-price-${cylinder.id}'),
                    style: type.value.copyWith(color: brasa.ink2)),
                if (promos.isNotEmpty)
                  Text(promos.map(Pricing.badge).join('  '),
                      style: type.caption.copyWith(color: brasa.accent)),
              ],
            ),
          ),
          SplgQuantityStepper(
            quantity: qty,
            onAdd: () => model.changeQuantity(cylinder, 1),
            onRemove: () => model.changeQuantity(cylinder, -1),
          ),
        ],
      ),
    );
  }
}
