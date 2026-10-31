import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'cart_viewmodel.dart';

/// Carrito del cliente (el del back): ítems, total, avisos y vaciar.
class CartView extends StackedView<CartViewModel> {
  const CartView({super.key});

  @override
  CartViewModel viewModelBuilder(BuildContext context) => CartViewModel();

  @override
  void onViewModelReady(CartViewModel viewModel) => viewModel.load();

  @override
  Widget builder(BuildContext context, CartViewModel model, Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    return LoadScaffold(
      title: 'Mi carrito',
      model: model,
      builder: (context) {
        final cart = model.cart;
        if (cart.isEmpty) {
          return SplgEmptyState(
            illustration: SplgIllustration.emptyList,
            message: 'Tu carrito está vacío.',
            action: SplgButton(
              key: const Key('cart-add-more-empty'),
              title: 'Agregar garrafas',
              onPressed: model.addMore,
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  if (cart.hasUnavailableItems)
                    _Notice(
                      key: const Key('cart-unavailable-notice'),
                      text: 'Hay garrafas que ya no están disponibles. '
                          'Quitalas para continuar.',
                      color: brasa.danger,
                    ),
                  if (cart.hasPriceChanges)
                    _Notice(
                      key: const Key('cart-price-notice'),
                      text: 'Cambió el precio de algunas garrafas. Se cobra '
                          'el precio de hoy.',
                      color: brasa.warn,
                    ),
                  if (model.actionError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(model.actionError!,
                          key: const Key('cart-error'),
                          style: type.body.copyWith(color: brasa.danger)),
                    ),
                  for (final line in cart.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LineTile(
                        line: line,
                        busy: model.isBusy,
                        onAdd: () => model.increment(line),
                        onSubtract: () => model.decrement(line),
                        onRemove: () => model.remove(line),
                      ),
                    ),
                  TextButton(
                    key: const Key('cart-clear'),
                    onPressed: model.isBusy
                        ? null
                        : () => _confirmClear(context, model),
                    child: const Text('Vaciar carrito'),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: type.label),
                        Text(money.format(cart.total),
                            key: const Key('cart-total'), style: type.amount),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SplgButton(
                      key: const Key('cart-add-more'),
                      title: 'Agregar garrafas',
                      style: SplgButtonStyle.outlined,
                      onPressed: model.isBusy ? null : model.addMore,
                    ),
                    const SizedBox(height: 8),
                    SplgButton(
                      key: const Key('cart-continue'),
                      title: 'Continuar',
                      loading: model.isBusy,
                      onPressed: model.canContinue ? model.goToCheckout : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, CartViewModel model) async {
    final ok = await showSplgDialog(
      context,
      title: 'Vaciar carrito',
      message: '¿Querés sacar todas las garrafas del carrito?',
      primaryLabel: 'Vaciar',
      secondaryLabel: 'Cancelar',
      destructive: true,
    );
    if (ok) await model.clear();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(SplgIcons.error, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: SplgType.of(context).body.copyWith(color: color))),
          ],
        ),
      );
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.busy,
    required this.onAdd,
    required this.onSubtract,
    required this.onRemove,
  });

  final CartLine line;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onSubtract;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final brasa = context.brasa;
    final type = SplgType.of(context);
    final name = line.type.trim().isEmpty ? 'Garrafa' : line.type.trim();
    final diff = line.priceDifference;
    final stepper = Container(
      decoration: BoxDecoration(
        color: brasa.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('cart-minus-${line.gasCylinderId}'),
            tooltip: 'Restar',
            color: brasa.primaryStrong,
            icon: const Icon(SplgIcons.minus),
            onPressed: busy || line.quantity <= 1 ? null : onSubtract,
          ),
          SizedBox(
            width: 28,
            child: Text('${line.quantity}',
                key: Key('cart-qty-${line.gasCylinderId}'),
                textAlign: TextAlign.center,
                style: type.value),
          ),
          IconButton(
            key: Key('cart-plus-${line.gasCylinderId}'),
            tooltip: 'Sumar',
            color: brasa.primaryStrong,
            icon: const Icon(SplgIcons.plus),
            onPressed: busy ? null : onAdd,
          ),
        ],
      ),
    );
    return Container(
      key: Key('cart-line-${line.gasCylinderId}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: line.available ? brasa.outline : brasa.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: type.subtitle)),
              IconButton(
                key: Key('cart-remove-${line.gasCylinderId}'),
                tooltip: 'Quitar',
                color: brasa.danger,
                icon: const Icon(SplgIcons.trash),
                onPressed: busy ? null : onRemove,
              ),
            ],
          ),
          if (!line.available)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SplgStatusBadge(
                  label: 'No disponible', tone: SplgTone.danger),
            )
          else ...[
            if (line.priceChanged)
              Text(
                'Antes ${money.format(line.savedUnitPrice)} '
                '(${diff > 0 ? '+' : '-'}${money.format(diff.abs())})',
                key: Key('cart-diff-${line.gasCylinderId}'),
                style: type.caption.copyWith(color: brasa.warn),
              ),
            if (!line.hasEnoughStock)
              Text('Stock justo: puede que no alcance para ${line.quantity}.',
                  key: Key('cart-stock-${line.gasCylinderId}'),
                  style: type.caption.copyWith(color: brasa.warn)),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(money.format(line.subtotal), style: type.heading),
                        Text('${money.format(line.currentUnitPrice)} c/u',
                            style: type.caption),
                      ],
                    ),
                  ),
                  stepper,
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
