import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';

/// Encabezado de las pantallas internas: flecha, título y la campana que abre
/// las notificaciones.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.bell = true,
    this.centerTitle = true,
    this.actions,
  });

  final String title;
  final bool bell;
  final bool centerTitle;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) => SplgHeader(
        title: title,
        centerTitle: centerTitle,
        actions: actions,
        onNotifications: bell
            ? () => locator<NavigationService>().navigateToNotificationsView()
            : null,
      );
}
