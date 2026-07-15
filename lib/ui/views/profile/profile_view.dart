import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'profile_viewmodel.dart';

class ProfileView extends StackedView<ProfileViewModel> {
  const ProfileView({super.key});

  @override
  Widget builder(
    BuildContext context,
    ProfileViewModel viewModel,
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
          'Mi Perfil',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withAlpha(100),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _ProfileField(
                            icon: Icons.person_outline,
                            label: 'Nombre',
                            value: viewModel.fullName,
                            onEdit: () => _promptEditField(
                              context,
                              title: 'Editar nombre',
                              initialValue: viewModel.fullName,
                              keyboardType: TextInputType.name,
                              onSave: viewModel.updateName,
                            ),
                          ),
                          _buildDivider(colorScheme),
                          _ProfileField(
                            icon: Icons.phone_outlined,
                            label: 'Teléfono',
                            value: viewModel.phoneNumber,
                            onEdit: () => _promptEditField(
                              context,
                              title: 'Editar teléfono',
                              initialValue: viewModel.phoneNumber,
                              keyboardType: TextInputType.phone,
                              onSave: viewModel.updatePhone,
                            ),
                          ),
                          _buildDivider(colorScheme),
                          _ProfileField(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: viewModel.email,
                          ),
                          _buildDivider(colorScheme),
                          _ProfileField(
                            icon: Icons.location_on_outlined,
                            label: 'Dirección',
                            value: viewModel.formattedAddress,
                            onEdit: viewModel.navigateToAddresses,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: viewModel.signOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cerrar sesión',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: viewModel.deleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Borrar cuenta',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra un diálogo con un campo de texto para editar un dato del perfil.
  /// [onSave] hace el PATCH y devuelve si se guardó; se avisa el resultado.
  Future<void> _promptEditField(
    BuildContext context, {
    required String title,
    required String initialValue,
    required TextInputType keyboardType,
    required Future<bool> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: keyboardType == TextInputType.name
              ? TextCapitalization.words
              : TextCapitalization.none,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty || value == initialValue.trim()) {
      return;
    }

    final ok = await onSave(value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Datos actualizados.' : 'No se pudo actualizar.'),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        color: colorScheme.onSurface.withAlpha(20),
      ),
    );
  }

  @override
  ProfileViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      ProfileViewModel();
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          color: colorScheme.onSurface.withAlpha(150),
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withAlpha(150),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
            splashRadius: 24,
          ),
      ],
    );
  }
}
