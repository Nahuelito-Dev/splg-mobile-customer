import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

import 'package:jennygas_lib/domain/order.dart';
import 'package:jennygas_lib/domain/order_item.dart';

import 'history_model.dart';

class History extends StackedView<HistoryModel> {
  const History({super.key});

  @override
  Widget builder(
    BuildContext context,
    HistoryModel viewModel,
    Widget? child,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.maybeOpenTracking();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Text(
            'Historial',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: viewModel.isBusy
              ? const Center(child: CircularProgressIndicator())
              : viewModel.history.isEmpty
                  ? Center(
                      child: Text(
                        'No hay órdenes en el historial',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: viewModel.history.length,
                      itemBuilder: (context, index) {
                        final order = viewModel.history[index];
                        return _OrderItemTile(
                          order: order,
                          onRepeatOrder: () => viewModel.repeatOrder(order),
                          onModifyOrder: () => viewModel.modifyOrder(order),
                          onCancelOrder: () => viewModel.cancelOrder(order),
                          onTrackOrder: () => viewModel.openTracking(order),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  HistoryModel viewModelBuilder(
    BuildContext context,
  ) =>
      HistoryModel();

  @override
  onViewModelReady(HistoryModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }
}

class _OrderItemTile extends StatelessWidget {
  final Order order;
  final VoidCallback onRepeatOrder;
  final VoidCallback onModifyOrder;
  final VoidCallback onCancelOrder;
  final VoidCallback onTrackOrder;

  const _OrderItemTile({
    required this.order,
    required this.onRepeatOrder,
    required this.onModifyOrder,
    required this.onCancelOrder,
    required this.onTrackOrder,
  });

  String _safeAddress(String? streetName) {
    final text = streetName?.trim();
    if (text == null || text.isEmpty) return 'Dirección no disponible';
    return text;
  }

  String _safeItemLabel(OrderItem item) {
    final type = item.cylinder.type.trim();
    if (type.isNotEmpty) {
      return type;
    }

    final description = item.cylinder.description.trim();
    if (description.isEmpty || _looksLikeCode(description)) {
      return 'Garrafa';
    }

    return description;
  }

  bool _looksLikeCode(String text) {
    return text.contains('import ') ||
        text.contains('function ') ||
        text.contains('className=') ||
        text.contains('<div') ||
        text.length > 120;
  }

  Future<void> _confirmCancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: const Text('Estas seguro de cancerlar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Si'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onCancelOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM. yyyy');
    final timeFormat = DateFormat('HH:mm');

    final String statusText;
    switch (order.status) {
      case OrderStatus.delivered:
        statusText = 'ENTREGADO';
        break;
      case OrderStatus.cancelled:
        statusText = 'CANCELADO';
        break;
      case OrderStatus.accepted:
        statusText = 'ASIGNADO';
        break;
      case OrderStatus.outForDelivery:
        statusText = 'EN CAMINO';
        break;
      default:
        statusText = order.status.name.toUpperCase();
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(100),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(30),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeAddress(order.address?.streetName),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      // Display all items
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${item.quantity}x ${_safeItemLabel(item)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withAlpha(150),
                                  ),
                            ),
                          )),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status == OrderStatus.cancelled
                        ? Theme.of(context).colorScheme.error
                        : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(order.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withAlpha(150),
                          ),
                    ),
                    Text(
                      timeFormat.format(order.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withAlpha(150),
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.currency(
                        locale: 'es_AR',
                        symbol: '\$',
                        decimalDigits: 0,
                        customPattern: '\u00A4#,##0',
                      ).format(order.total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (order.status == OrderStatus.pending)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _confirmCancelOrder(context),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: onModifyOrder,
                            child: const Text('Modificar'),
                          ),
                        ],
                      )
                    else if (order.status == OrderStatus.accepted ||
                        order.status == OrderStatus.outForDelivery)
                      TextButton(
                        onPressed: onTrackOrder,
                        child: const Text('Seguir pedido'),
                      )
                    else
                      TextButton(
                        onPressed: onRepeatOrder,
                        child: const Text('Repetir pedido'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
