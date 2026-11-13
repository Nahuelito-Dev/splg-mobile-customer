import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'orders_viewmodel.dart';

class OrdersView extends StackedView<OrdersViewModel> {
  const OrdersView({super.key});

  @override
  OrdersViewModel viewModelBuilder(BuildContext context) => OrdersViewModel();

  @override
  void onViewModelReady(OrdersViewModel viewModel) => viewModel.load();

  @override
  Widget builder(BuildContext context, OrdersViewModel model, Widget? child) {
    return LoadScaffold(
      title: 'Mis pedidos',
      model: model,
      builder: (context) {
        if (model.orders.isEmpty) {
          return const SplgEmptyState(
            message: 'Todavía no hiciste ningún pedido.',
          );
        }
        return _OrdersList(model: model);
      },
    );
  }
}

/// Lista de pedidos; al llegar al final pide la página siguiente.
class _OrdersList extends StatefulWidget {
  const _OrdersList({required this.model});

  final OrdersViewModel model;

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final model = widget.model;
    if (model.moreError != null) return;
    if (_scroll.position.extentAfter < 300) model.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final type = SplgType.of(context);
    final orders = model.orders;
    final hasFooter =
        model.loadingMore || model.moreError != null || model.hasMore;
    return RefreshIndicator(
      onRefresh: model.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: orders.length + (hasFooter ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i >= orders.length) {
            if (model.moreError != null) {
              return Column(
                children: [
                  Text(model.moreError!,
                      key: const Key('orders-more-error'),
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(color: context.brasa.danger)),
                  const SizedBox(height: 8),
                  SplgButton(
                    title: 'Cargar más',
                    style: SplgButtonStyle.outlined,
                    expand: false,
                    onPressed: () => model.loadMore(retry: true),
                  ),
                ],
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(height: 40, child: SplgLoader()),
            );
          }
          final o = orders[i];
          final street = o.address?.streetName.trim() ?? '';
          return SplgOrderCard(
            key: Key('order-${o.id}'),
            icon: SplgIcons.location,
            title: street.isEmpty ? 'Dirección no disponible' : street,
            subtitle: dateTimeLabel(o.createdAt),
            detail:
                '${o.items.map(itemLabel).join(', ')} · ${money.format(o.total)} · ${orderPaymentLabel(o)}',
            badge: orderStatusLabel(o),
            badgeTone: orderStatusTone(o),
            highlighted: isActive(o.status),
            onTap: () => model.open(o),
          );
        },
      ),
    );
  }
}
