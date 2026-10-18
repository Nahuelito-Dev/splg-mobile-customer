import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'app_drawer_viewmodel.dart';

/// Menú lateral del cliente: pantalla completa sobre el degradé de marca, con
/// las entradas agrupadas por línea. Cada ítem cierra el menú y navega.
class AppDrawer extends StackedView<AppDrawerViewModel> {
  const AppDrawer({super.key});

  @override
  AppDrawerViewModel viewModelBuilder(BuildContext context) =>
      AppDrawerViewModel();

  @override
  void onViewModelReady(AppDrawerViewModel viewModel) => viewModel.loadPhoto();

  @override
  Widget builder(
      BuildContext context, AppDrawerViewModel model, Widget? child) {
    Widget item(String label, IconData icon, Future<void> Function() go) =>
        SplgMenuItem(
          dark: true,
          label: label,
          icon: icon,
          onTap: () {
            Navigator.of(context).pop();
            go();
          },
        );

    Widget line() => const Divider(
        indent: 15,
        endIndent: 15,
        thickness: 2,
        height: 20,
        color: Colors.white70);

    Widget group(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(children: children),
        );

    return Drawer(
      width: MediaQuery.of(context).size.width,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      backgroundColor: Colors.transparent,
      child: SplgGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Cerrar menú',
                      icon: const Icon(SplgIcons.back,
                          size: 24, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('Menú',
                        style: SplgType.of(context).heading.copyWith(
                            color: Colors.white, fontSize: context.sp(14))),
                    IconButton(
                      tooltip: 'Notificaciones',
                      icon: const Icon(SplgIcons.bell,
                          size: 24, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                        model.openNotifications();
                      },
                    ),
                  ],
                ),
                line(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      SplgAvatar(
                        key: const Key('drawer-avatar'),
                        imageUrl: model.photoUrl,
                        initials: model.initials,
                        radius: 34,
                      ),
                      if (model.fullName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(model.fullName,
                              style: SplgType.of(context)
                                  .subtitle
                                  .copyWith(color: Colors.white)),
                        ),
                    ],
                  ),
                ),
                line(),
                group([
                  item('Mi perfil', SplgIcons.user, model.openProfile),
                  item('Mis pedidos', SplgIcons.deliveries, model.openOrders),
                  item('Mis direcciones', SplgIcons.location,
                      model.openAddresses),
                ]),
                line(),
                group([
                  item('Mis reclamos', SplgIcons.claim, model.openClaims),
                  item('Notificaciones', SplgIcons.bell,
                      model.openNotifications),
                ]),
                line(),
                group([
                  item('Ayuda', SplgIcons.help, model.openHelp),
                  item('Términos y condiciones', SplgIcons.terms,
                      model.openTerms),
                  item('Políticas de privacidad', SplgIcons.privacy,
                      model.openPrivacy),
                  item('Acerca de SPLG', SplgIcons.about, model.openAbout),
                ]),
                line(),
                group([
                  SplgMenuItem(
                    dark: true,
                    destructive: true,
                    label: 'Cerrar sesión',
                    icon: SplgIcons.logout,
                    onTap: () => _confirmLogout(context, model),
                  ),
                ]),
                const Divider(
                    indent: 15,
                    endIndent: 15,
                    thickness: 2,
                    color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(
      BuildContext context, AppDrawerViewModel model) async {
    final ok = await showSplgDialog(
      context,
      title: '¿Querés cerrar sesión?',
      message: 'Tus datos y tus pedidos no se pierden al cerrar sesión.',
      primaryLabel: 'Cerrar sesión',
      secondaryLabel: 'Cancelar',
      illustration: SplgIllustration.welcome,
    );
    if (ok && context.mounted) {
      Navigator.of(context).pop();
      await model.logout();
    }
  }
}
