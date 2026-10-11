import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'account_model.dart';

class Account extends StackedView<AccountModel> {
  const Account({super.key});

  @override
  Widget builder(
    BuildContext context,
    AccountModel viewModel,
    Widget? child,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Configuraciones',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 32),
        _profileOption(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.person_outline,
          title: 'Perfil',
          onTap: viewModel.navigateToProfile,
        ),
        _profileOption(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.description_outlined,
          title: 'Términos y Condiciones',
          onTap: viewModel.navigateToTerms,
        ),
        _profileOption(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.lock_outline,
          title: 'Privacidad',
          onTap: viewModel.navigateToPrivacyPolicy,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _profileOption({
    required BuildContext context,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withAlpha(100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.onSurface),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurface.withAlpha(120),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  AccountModel viewModelBuilder(
    BuildContext context,
  ) =>
      AccountModel();
}
