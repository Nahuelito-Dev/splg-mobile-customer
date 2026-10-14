import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

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
                                if (_promo(model, item) != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      _promo(model, item)!,
                                      style: type.caption.copyWith(
                                          color: context.brasa.accent),
                                    ),
                                  ),
                                Text(
                                    model.quoteLineFor(item) == null
                                        ? '—'
                                        : money.format(
                                            model.quoteLineFor(item)!.subtotal),
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
                                Text(
                                    model.quote == null
                                        ? '—'
                                        : money.format(model.quote!.total),
                                    key: const Key('checkout-total'),
                                    style: type.amount
                                        .copyWith(color: Colors.white)),
                              ],
                            ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (model.quoting)
                                    Text('Calculando…',
                                        key: const Key('checkout-quoting'),
                                        style: type.caption
                                            .copyWith(color: Colors.white70)),
                                  if ((model.quote?.zoneSurcharge ?? 0) > 0)
                                    Text(
                                        'Recargo por zona ${money.format(model.quote!.zoneSurcharge)}',
                                        key: const Key(
                                            'checkout-zone-surcharge'),
                                        textAlign: TextAlign.right,
                                        style: type.caption
                                            .copyWith(color: Colors.white70)),
                                  if ((model.quote?.paymentSurcharge ?? 0) > 0)
                                    Text(
                                        'Recargo por medio de pago ${money.format(model.quote!.paymentSurcharge)}',
                                        key: const Key(
                                            'checkout-payment-surcharge'),
                                        textAlign: TextAlign.right,
                                        style: type.caption
                                            .copyWith(color: Colors.white70)),
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
                            key: const Key('checkout-quote-error'),
                            onTap:
                                model.canRetryQuote ? model.retryQuote : null,
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
                            title: paymentLabel(m),
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

/// Insignia de la promoción por volumen que aplicó el back: el precio unitario
/// de la cotización contra el de lista de la garrafa.
String? _promo(CheckoutViewModel model, OrderItem item) {
  final line = model.quoteLineFor(item);
  final list = item.cylinder.price;
  if (line == null || list <= 0 || line.unitPrice >= list) return null;
  final pct = (1 - line.unitPrice / list) * 100;
  return '−${pct.toStringAsFixed(0)}% x${item.quantity}';
}
