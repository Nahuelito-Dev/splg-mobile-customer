import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

import 'checkout_viewmodel.dart';

import 'package:splg_customer/domain/time_slot_availability.dart';
import 'widgets/cylinder_checkout_item.dart';
import 'widgets/payment_method_selector.dart';

class CheckoutView extends StackedView<CheckoutViewModel> {
  const CheckoutView({super.key});

  @override
  Widget builder(
    BuildContext context,
    CheckoutViewModel viewModel,
    Widget? child,
  ) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0',
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (viewModel.order != null) ...[
                      // Order Items
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh
                              .withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withAlpha(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: viewModel.order!.items.length,
                              separatorBuilder: (_, __) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(
                                  height: 1,
                                  color:
                                      theme.colorScheme.onSurface.withAlpha(20),
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final item = viewModel.order!.items[index];
                                return CylinderCheckoutItem(
                                  item: item,
                                  subtotal: viewModel.getSubtotal(item),
                                  appliedDiscount:
                                      viewModel.getAppliedDiscount(item),
                                  currencyFormat: currencyFormat,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Divider(
                              color: theme.colorScheme.onSurface.withAlpha(20),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(viewModel.finalTotal),
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Payment Method
                      PaymentMethodSelector(
                        selectedMethod: viewModel.selectedPaymentMethod,
                        onMethodChanged: viewModel.setPaymentMethod,
                      ),
                      const SizedBox(height: 24),

                      // Delivery Date Selection
                      Text(
                        'Fecha de entrega',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => viewModel.selectDate(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline.withAlpha(70),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surface.withAlpha(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                viewModel.formattedDate,
                                style: theme.textTheme.bodyLarge,
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Franja de entrega (agendamiento por TimeSlots)
                      Text(
                        'Franja de entrega',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTimeSlotSelector(theme, viewModel),
                      const SizedBox(height: 24),

                      // Address Input
                      Text(
                        'Dirección de entrega',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAddressView(theme, viewModel),
                      const SizedBox(height: 24),

                      // Delivery Details
                      Text(
                        'Detalles del entrega (Opcional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: viewModel.deliveryDetailsController,
                        maxLines: null,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Ej: Tocar timbre, dejar en portería...',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                          fillColor: theme.colorScheme.surface.withAlpha(20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withAlpha(70),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withAlpha(70),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: viewModel.canConfirmOrder && !viewModel.isBusy
                      ? viewModel.confirmOrder
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'CONFIRMAR PEDIDO',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de franja horaria: chips con las franjas disponibles para la
  /// fecha elegida. Las llenas (sin cupo) quedan deshabilitadas. Muestra
  /// loader mientras trae, y un aviso si no hay franjas ese día.
  Widget _buildTimeSlotSelector(ThemeData theme, CheckoutViewModel viewModel) {
    if (viewModel.loadingTimeSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final slots = viewModel.timeSlots;
    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withAlpha(70)),
        ),
        child: Text(
          'No hay franjas disponibles para esta fecha. Probá con otro día.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(160),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((TimeSlotAvailability slot) {
        final selected = slot.timeSlotId == viewModel.selectedTimeSlotId;
        return ChoiceChip(
          label: Text(slot.isFull ? '${slot.label} · sin cupo' : slot.label),
          selected: selected,
          onSelected: slot.isFull
              ? null
              : (_) => viewModel.selectTimeSlot(slot.timeSlotId),
          labelStyle: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withAlpha(slot.isFull ? 90 : 220),
          ),
          selectedColor: theme.colorScheme.primary,
        );
      }).toList(),
    );
  }

  Widget _buildAddressView(ThemeData theme, CheckoutViewModel viewModel) {
    final OutlineInputBorder outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: theme.colorScheme.outline.withAlpha(70),
      ),
    );

    return TextField(
      controller: viewModel.addressController,
      readOnly: true,
      onTap: () => viewModel.openMap(),
      decoration: InputDecoration(
        hintText: 'Dirección',
        fillColor: theme.colorScheme.surface.withAlpha(20),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: IconButton(
            icon: Icon(Icons.location_on, color: theme.colorScheme.primary),
            onPressed: () => viewModel.openMap(),
          ),
        ),
        prefixIcon: IconButton(
          icon: Icon(Icons.list, color: theme.colorScheme.primary),
          onPressed: viewModel.showAddressList,
        ),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  CheckoutViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      CheckoutViewModel();

  @override
  void onViewModelReady(CheckoutViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }
}
