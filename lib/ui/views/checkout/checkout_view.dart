import 'package:splg_customer/domain/pricing.dart';
import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/delivery_options.dart';
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

    Widget surcharge(Key key, String label, num amount) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: type.caption.copyWith(color: Colors.white70))),
              Text(money.format(amount),
                  style: type.caption.copyWith(color: Colors.white70)),
            ],
          ),
        );

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
                      const SizedBox(height: 6),
                      if (model.quoting)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('Calculando…',
                              key: const Key('checkout-quoting'),
                              style:
                                  type.caption.copyWith(color: Colors.white70)),
                        ),
                      if ((model.quote?.zoneSurcharge ?? 0) > 0)
                        surcharge(const Key('checkout-zone-surcharge'),
                            'Recargo por zona', model.quote!.zoneSurcharge),
                      if ((model.quote?.expressSurcharge ?? 0) > 0)
                        surcharge(const Key('checkout-express-surcharge'),
                            'Recargo express', model.quote!.expressSurcharge),
                      if ((model.quote?.paymentSurcharge ?? 0) > 0)
                        surcharge(
                            const Key('checkout-payment-surcharge'),
                            paymentSurchargeLabel(model.quote!.paymentMethod,
                                model.quote!.paymentSurchargePercentage),
                            model.quote!.paymentSurcharge),
                      const SizedBox(height: 8),
                      divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text('Total',
                                  style: type.label
                                      .copyWith(color: Colors.white70)),
                            ),
                            Text(
                                model.quote == null
                                    ? '—'
                                    : money.format(model.quote!.total),
                                key: const Key('checkout-total'),
                                style:
                                    type.amount.copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                        child: Text(Pricing.ivaIncluido,
                            key: const Key('checkout-iva'),
                            style: type.caption
                                .copyWith(color: Colors.white70)),
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
                      if (model.showDeliveryChoice) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 10, 6, 2),
                          child: Text('Modalidad de entrega',
                              style:
                                  type.caption.copyWith(color: Colors.white70)),
                        ),
                        SplgRadioRow(
                          key: const Key('mode-standard'),
                          onDark: true,
                          icon: SplgIcons.truck,
                          title: 'Entrega normal',
                          subtitle: _modeSubtitle(model.standardOption),
                          selected: !model.isExpress,
                          onTap: model.isBusy
                              ? null
                              : () =>
                                  model.setDeliveryMode(DeliveryMode.standard),
                        ),
                        SplgRadioRow(
                          key: const Key('mode-express'),
                          onDark: true,
                          icon: SplgIcons.online,
                          title: 'Entrega express',
                          subtitle: _modeSubtitle(model.expressOption),
                          selected: model.isExpress,
                          onTap: model.isBusy ||
                                  !(model.expressOption?.available ?? false)
                              ? null
                              : () =>
                                  model.setDeliveryMode(DeliveryMode.express),
                        ),
                        divider(),
                      ],
                      if (model.deliveryNotice != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                          child: Text(model.deliveryNotice!,
                              key: const Key('checkout-delivery-notice'),
                              style:
                                  type.caption.copyWith(color: Colors.white)),
                        ),
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
                      if (model.isExpress)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 12),
                          child: Text(
                              'El pedido express sale ahora: no se agenda '
                              'fecha ni franja.',
                              key: const Key('checkout-express-note'),
                              style: white),
                        )
                      else ...[
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
                                    : () =>
                                        model.selectTimeSlot(slot.timeSlotId),
                              ),
                      ],
                      divider(),
                      SplgOptionRow(
                        key: const Key('checkout-receiver'),
                        onDark: true,
                        icon: SplgIcons.user,
                        title: 'Quién recibe',
                        value: model.receiver?.name ?? 'Yo (opcional)',
                        onTap: model.editReceiver,
                      ),
                      if (model.receiver != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('checkout-receiver-clear'),
                            onPressed: model.clearReceiver,
                            child: const Text('Quitar',
                                style: TextStyle(color: Colors.white)),
                          ),
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

/// Insignia de la promoción por volumen que aplicó el back en la cotización.
String? _promo(CheckoutViewModel model, OrderItem item) {
  final pct = model.quoteLineFor(item)?.discountPercentage;
  if (pct == null) return null;
  return '−${pct.toStringAsFixed(0)}% x${item.quantity}';
}

/// Demora y recargo de una modalidad, o por qué no se puede elegir.
String? _modeSubtitle(DeliveryOption? option) {
  if (option == null) return null;
  if (!option.available) return option.unavailableText;
  final parts = <String>[
    if (option.estimatedMinutes != null) '~${option.estimatedMinutes} min',
    if (option.surchargeAmount > 0) '+ ${money.format(option.surchargeAmount)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
