import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

import 'order_model.dart';
import 'package:jennygas_lib/domain/gas_cylinder.dart';

class Order extends StackedView<OrderModel> {
  const Order({super.key});

  @override
  void onViewModelReady(OrderModel viewModel) {
    viewModel.initialize();
  }

  @override
  Widget builder(
    BuildContext context,
    OrderModel viewModel,
    Widget? child,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0',
    );

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Image.asset(
                'assets/logo.png',
                height: 60,
                cacheWidth: 635,
                cacheHeight: 180,
              ),
            ),
            if (viewModel.hasActiveOrder)
              _ActiveOrderCard(
                orderCode: viewModel.activeOrderShortCode,
                statusLabel: viewModel.activeOrderStatusLabel,
                onTap: viewModel.openActiveOrderTracking,
              ),
            if (viewModel.hasActiveOrder) const SizedBox(height: 12),
            Expanded(
              child: viewModel.isBusy
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 130),
                      itemCount: viewModel.cylinders.length,
                      itemBuilder: (context, index) {
                        final cylinder = viewModel.cylinders[index];
                        return _CylinderItemTile(
                          cylinder: cylinder,
                          quantity: viewModel.getItemQuantity(cylinder.id),
                          onAdd: () => viewModel.addItem(cylinder, 1),
                          onRemove: () => viewModel.addItem(cylinder, -1),
                          currencyFormat: currencyFormat,
                        );
                      },
                    ),
            ),
          ],
        ),
        if (viewModel.canPlaceOrder)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _OrderSummary(
              total: viewModel.total,
              onOrder: viewModel.placeOrder,
              currencyFormat: currencyFormat,
              enabled: viewModel.canPlaceOrder,
            ),
          ),
      ],
    );
  }

  @override
  OrderModel viewModelBuilder(BuildContext context) => OrderModel();
}

class _CylinderItemTile extends StatelessWidget {
  final GasCylinder cylinder;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final NumberFormat currencyFormat;

  const _CylinderItemTile({
    required this.cylinder,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _showCylinderDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: quantity > 0
              ? colorScheme.secondary.withAlpha(120)
              : colorScheme.onSurface.withAlpha(20),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/cylinder_10.png',
            height: 60,
            fit: BoxFit.contain,
            cacheWidth: 100,
            cacheHeight: 180,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garrafa de ${cylinder.type}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(cylinder.price),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withAlpha(180),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (cylinder.discounts != null &&
                    cylinder.discounts!.isNotEmpty)
                  ...cylinder.discounts!.map((discount) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '-${discount.percentage.toStringAsFixed(0)}% a partir de ${discount.quantity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      )),
                const SizedBox(height: 12),
                Text(
                  'Métodos de pago',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.credit_card,
                        size: 18, color: colorScheme.onSurface.withAlpha(150)),
                    SizedBox(width: 8),
                    Icon(Icons.payments_outlined,
                        size: 18, color: colorScheme.onSurface.withAlpha(150)),
                    SizedBox(width: 8),
                    Icon(Icons.account_balance_outlined,
                        size: 18, color: colorScheme.onSurface.withAlpha(150)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
                color: colorScheme.primary,
              ),
              Text(
                '$quantity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: quantity > 0 ? onRemove : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: quantity > 0 ? colorScheme.error : colorScheme.outline,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  void _showCylinderDetail(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CylinderDetailSheet(
        cylinder: cylinder,
        currencyFormat: currencyFormat,
        onAdd: onAdd,
      ),
    );
  }
}

/// Popup de detalle de una garrafa: imagen, precio, promociones con el precio
/// unitario ya calculado por tramo, métodos de pago y botón para agregar.
class _CylinderDetailSheet extends StatelessWidget {
  final GasCylinder cylinder;
  final NumberFormat currencyFormat;
  final VoidCallback onAdd;

  const _CylinderDetailSheet({
    required this.cylinder,
    required this.currencyFormat,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final discounts = cylinder.discounts ?? const [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                'assets/cylinder_10.png',
                height: 140,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Garrafa de ${cylinder.type}',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${cylinder.weight} kg',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurface.withAlpha(150)),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(cylinder.price),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            if (cylinder.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                cylinder.description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface.withAlpha(180)),
              ),
            ],
            if (discounts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Promociones por cantidad',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...discounts.map((d) {
                final unit = cylinder.price * (1 - d.percentage / 100);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('−${d.percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Llevando ${d.quantity} o más: ${currencyFormat.format(unit)} c/u',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
            Text('Métodos de pago',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _payRow(theme, Icons.payments_outlined, 'Efectivo',
                'Pagás al recibir el pedido'),
            _payRow(theme, Icons.account_balance_outlined, 'Transferencia',
                'Recargo del 10%'),
            _payRow(theme, Icons.credit_card, 'MercadoPago',
                'Tarjeta de crédito/débito'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  onAdd();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar al carrito'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payRow(
      ThemeData theme, IconData icon, String title, String subtitle) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colorScheme.onSurface.withAlpha(170)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurface.withAlpha(130))),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final double total;
  final VoidCallback onOrder;
  final NumberFormat currencyFormat;
  final bool enabled;

  const _OrderSummary({
    required this.total,
    required this.onOrder,
    required this.currencyFormat,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleLarge,
              ),
              Text(
                currencyFormat.format(total),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: enabled ? colorScheme.primary : colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? onOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: enabled
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Pedir',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: enabled
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant.withAlpha(100),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.orderCode,
    required this.statusLabel,
    required this.onTap,
  });

  final String orderCode;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido en curso #$orderCode',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Ver seguimiento'),
          ),
        ],
      ),
    );
  }
}
