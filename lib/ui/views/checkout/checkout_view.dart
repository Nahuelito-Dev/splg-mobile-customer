import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'checkout_viewmodel.dart';

/// Confirmación del pedido: dirección, total, forma de pago, cuándo y franja,
/// sobre el degradé de marca.
class CheckoutView extends StackedView<CheckoutViewModel> {
  const CheckoutView({super.key});

  @override
  Widget builder(
    BuildContext context,
    CheckoutViewModel model,
    Widget? child,
  ) {
    final type = SplgType.of(context);
    final order = model.order;
    final white = type.body.copyWith(color: Colors.white);

    Widget divider() => const Divider(color: Colors.white24, height: 1);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const SplgHeader(title: 'Confirmación', onGradient: true),
      body: SplgGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SplgAddressPill(
                        key: const Key('checkout-address'),
                        text: model.addressController.text.isEmpty
                            ? 'Elegí tu dirección de entrega'
                            : model.addressController.text,
                        onDark: true,
                        onTap: model.showAddressList,
                      ),
                      const SizedBox(height: 14),
                      if (order != null)
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(itemLabel(item), style: white),
                                ),
                                if (Pricing.applied(
                                        item.cylinder, item.quantity) !=
                                    null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      Pricing.badge(Pricing.applied(
                                          item.cylinder, item.quantity)!),
                                      style: type.caption.copyWith(
                                          color: context.brasa.accent),
                                    ),
                                  ),
                                Text(money.format(model.getSubtotal(item)),
                                    style: type.value
                                        .copyWith(color: Colors.white)),
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
                                    style: type.caption
                                        .copyWith(color: Colors.white70)),
                                Text(money.format(model.finalTotal),
                                    key: const Key('checkout-total'),
                                    style: type.amount
                                        .copyWith(color: Colors.white)),
                              ],
                            ),
                            if (model.transferSurcharge > 0)
                              Flexible(
                                child: Text(
                                    'Incluye recargo de ${money.format(model.transferSurcharge)}',
                                    textAlign: TextAlign.right,
                                    style: type.caption
                                        .copyWith(color: Colors.white70)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      divider(),
                      SplgOptionRow(
                        key: const Key('checkout-payment'),
                        onDark: true,
                        dropdown: true,
                        icon: SplgIcons.cash,
                        title: 'Forma de pago',
                        value: paymentLabel(model.selectedPaymentMethod),
                        onTap: model.togglePayment,
                      ),
                      if (model.paymentOpen)
                        for (final m in PaymentMethod.values)
                          SplgRadioRow(
                            key: Key('pay-${m.name}'),
                            onDark: true,
                            title: m == PaymentMethod.online
                                ? 'Transferencia (+10%)'
                                : paymentLabel(m),
                            selected: model.selectedPaymentMethod == m,
                            onTap: () => model.setPaymentMethod(m),
                          ),
                      divider(),
                      SplgOptionRow(
                        key: const Key('checkout-date'),
                        onDark: true,
                        icon: SplgIcons.calendar,
                        title: 'Fecha de entrega',
                        value: model.formattedDate,
                        onTap: () => model.selectDate(context),
                      ),
                      divider(),
                      SplgOptionRow(
                        key: const Key('checkout-slots'),
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
                              key: Key('slot-${slot.timeSlotId}'),
                              onDark: true,
                              title: slot.label,
                              subtitle: slot.isFull
                                  ? 'Sin cupo'
                                  : 'Quedan ${slot.remaining}',
                              selected:
                                  slot.timeSlotId == model.selectedTimeSlotId,
                              onTap: slot.isFull
                                  ? null
                                  : () => model.selectTimeSlot(slot.timeSlotId),
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
                          controller: model.deliveryDetailsController,
                          hint: 'Ej: tocar timbre, dejar en portería…',
                          maxLength: 300,
                          minLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SplgButton(
                      title: 'Confirmar pedido',
                      style: SplgButtonStyle.white,
                      loading: model.isBusy,
                      onPressed:
                          model.canConfirmOrder ? model.confirmOrder : null,
                    ),
                    const SizedBox(height: 10),
                    SplgButton(
                      title: 'Cancelar',
                      style: SplgButtonStyle.ghost,
                      onPressed: model.isBusy
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

  @override
  CheckoutViewModel viewModelBuilder(BuildContext context) =>
      CheckoutViewModel();

  @override
  void onViewModelReady(CheckoutViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }
}
