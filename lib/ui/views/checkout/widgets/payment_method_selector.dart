import 'package:flutter/material.dart';
import 'package:splg_lib/domain/order.dart';

class PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onMethodChanged;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleccionar forma de pago',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _buildRadioOption(
            context,
            PaymentMethod.cash,
            'Efectivo',
          ),
          _buildRadioOption(
            context,
            PaymentMethod.online,
            'Transferencia (+10%)',
          ),
          _buildRadioOption(
            context,
            PaymentMethod.mercadoPago,
            'Mercado Pago',
          ),
        ],
      );
  }

  Widget _buildRadioOption(
      BuildContext context, PaymentMethod value, String label) {
    final theme = Theme.of(context);
    final isSelected = selectedMethod == value;

    return InkWell(
      onTap: () => onMethodChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        child: Row(
          children: [
            Radio<PaymentMethod>(
              value: value,
              groupValue: selectedMethod,
              onChanged: (val) {
                if (val != null) onMethodChanged(val);
              },
              activeColor: theme.colorScheme.primary,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
