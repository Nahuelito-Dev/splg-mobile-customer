import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/load_scaffold.dart';
import 'addresses_viewmodel.dart';

/// Gestión de direcciones del cliente: listar, agregar, editar, marcar
/// predeterminada y eliminar.
class AddressesView extends StackedView<AddressesViewModel> {
  const AddressesView({super.key});

  @override
  AddressesViewModel viewModelBuilder(BuildContext context) =>
      AddressesViewModel();

  @override
  void onViewModelReady(AddressesViewModel viewModel) => viewModel.load();

  @override
  Widget builder(
      BuildContext context, AddressesViewModel model, Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    return LoadScaffold(
      title: 'Mis direcciones',
      model: model,
      builder: (context) {
        final list = model.addresses;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Material(
              color: brasa.primaryStrong.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: SplgMenuItem(
                key: const Key('address-new'),
                label: 'Nueva dirección',
                icon: SplgIcons.plus,
                onTap: model.add,
              ),
            ),
            if (model.actionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(model.actionError!,
                    key: const Key('address-error'),
                    style: type.body.copyWith(color: brasa.danger)),
              ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              SizedBox(
                height: 360,
                child: SplgEmptyState(
                  illustration: SplgIllustration.location,
                  message: 'Todavía no tenés direcciones guardadas.',
                ),
              )
            else
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AddressTile(
                    key: Key('address-${a.addressId}'),
                    address: a,
                    busy: model.isBusy,
                    onEdit: () => model.edit(a),
                    onDefault: () => model.setDefault(a),
                    onDelete: () => _confirmDelete(context, model, a),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AddressesViewModel model, Address a) async {
    final ok = await showSplgDialog(
      context,
      title: 'Eliminar dirección',
      message: '¿Querés eliminar "${a.streetName}"?',
      primaryLabel: 'Eliminar',
      secondaryLabel: 'Cancelar',
      destructive: true,
    );
    if (ok) await model.delete(a);
  }
}

enum _Action { edit, makeDefault, delete }

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    super.key,
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onDefault,
    required this.onDelete,
  });

  final Address address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brasa = context.brasa;
    final type = SplgType.of(context);
    final detail = [
      if ((address.city ?? '').isNotEmpty) address.city!,
      if ((address.additionalInstructions ?? '').isNotEmpty)
        address.additionalInstructions!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: address.primary ? brasa.primaryStrong : brasa.outline,
            width: 2),
      ),
      child: Row(
        children: [
          Icon(SplgIcons.location, color: brasa.primaryStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                        child: Text(address.streetName, style: type.value)),
                    if (address.primary) ...[
                      const SizedBox(width: 8),
                      const SplgStatusBadge(
                          label: 'Predeterminada', tone: SplgTone.success),
                    ],
                  ],
                ),
                if (detail.isNotEmpty) Text(detail, style: type.caption),
              ],
            ),
          ),
          PopupMenuButton<_Action>(
            tooltip: 'Opciones',
            enabled: !busy,
            icon: Icon(SplgIcons.more, color: brasa.primaryStrong),
            onSelected: (a) => switch (a) {
              _Action.edit => onEdit(),
              _Action.makeDefault => onDefault(),
              _Action.delete => onDelete(),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: _Action.edit, child: Text('Editar')),
              if (!address.primary)
                const PopupMenuItem(
                    value: _Action.makeDefault,
                    child: Text('Marcar como predeterminada')),
              const PopupMenuItem(
                  value: _Action.delete, child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}
