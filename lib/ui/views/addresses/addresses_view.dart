import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'package:jennygas_lib/domain/address.dart';

import 'addresses_viewmodel.dart';

/// Gestión de direcciones del cliente: listar, agregar (vía mapa), marcar
/// predeterminada y eliminar.
class AddressesView extends StackedView<AddressesViewModel> {
  const AddressesView({super.key});

  @override
  Widget builder(
    BuildContext context,
    AddressesViewModel viewModel,
    Widget? child,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        title: Text(
          'Mis direcciones',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: viewModel.isBusy ? null : viewModel.addAddress,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar'),
      ),
      body: SafeArea(
        child: viewModel.isBusy
            ? const Center(child: CircularProgressIndicator())
            : viewModel.addresses.isEmpty
                ? _buildEmpty(theme)
                : _buildList(context, viewModel, colorScheme),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Todavía no tenés direcciones guardadas.\n'
              'Agregá una con el botón de abajo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AddressesViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: viewModel.addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final address = viewModel.addresses[index];
        return _AddressCard(
          address: address,
          colorScheme: colorScheme,
          onSetDefault: () => viewModel.setDefault(address),
          onDelete: () => _confirmDelete(context, viewModel, address),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AddressesViewModel viewModel,
    Address address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${address.streetName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.deleteAddress(address);
    }
  }

  @override
  AddressesViewModel viewModelBuilder(BuildContext context) =>
      AddressesViewModel();

  @override
  void onViewModelReady(AddressesViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.colorScheme,
    required this.onSetDefault,
    required this.onDelete,
  });

  final Address address;
  final ColorScheme colorScheme;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (address.city != null && address.city!.isNotEmpty) address.city!,
      if (address.postalCode != null && address.postalCode!.isNotEmpty)
        address.postalCode!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.primary
              ? colorScheme.primary
              : colorScheme.onSurface.withAlpha(30),
          width: address.primary ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.streetName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 8),
                if (address.primary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Predeterminada',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: onSetDefault,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Marcar como predeterminada'),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}
