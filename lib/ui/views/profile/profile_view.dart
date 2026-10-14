import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/photo_source_sheet.dart';
import 'package:splg_customer/ui/widgets/app_header.dart';
import 'profile_viewmodel.dart';
import 'package:splg_customer/ui/common/app_icons.dart';

class ProfileView extends StackedView<ProfileViewModel> {
  const ProfileView({super.key});

  @override
  ProfileViewModel viewModelBuilder(BuildContext context) => ProfileViewModel();

  @override
  void onViewModelReady(ProfileViewModel viewModel) => viewModel.loadPhoto();

  @override
  Widget builder(BuildContext context, ProfileViewModel model, Widget? child) {
    final brasa = context.brasa;
    return Scaffold(
      appBar: const AppHeader(title: 'Mi perfil'),
      body: SafeArea(
        child: model.isBusy
            ? const SplgLoader()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: [
                    SplgProfileHeader(
                      name: model.fullName,
                      phone: model.phoneNumber,
                      initials: model.initials,
                      imageUrl: model.photoUrl,
                      linkLabel: 'Editar perfil',
                      onLink: model.editProfile,
                    ),
                    _PhotoActions(model: model),
                    Divider(color: brasa.primaryStrong, height: 16),
                    SplgMenuItem(
                      label: 'Información personal',
                      selected: model.selected == 0,
                      icon: SplgIcons.user,
                      onTap: model.openPersonalInfo,
                    ),
                    SplgMenuItem(
                      label: 'Cambiar contraseña',
                      selected: model.selected == 1,
                      icon: SplgIcons.key,
                      onTap: model.openChangePassword,
                    ),
                    SplgMenuItem(
                      label: 'Mis direcciones',
                      selected: model.selected == 2,
                      icon: SplgIcons.location,
                      onTap: model.openAddresses,
                    ),
                    SplgMenuItem(
                      label: 'Eliminar cuenta',
                      selected: model.selected == 3,
                      icon: SplgIcons.userMinus,
                      onTap: () => _confirmDelete(context, model),
                    ),
                    Divider(color: brasa.primaryStrong, height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ProfileViewModel model) async {
    final ok = await showSplgDialog(
      context,
      title: '¿Eliminar tu cuenta?',
      message: 'Es definitiva: no vas a poder volver a ingresar y tu email '
          'queda reservado, así que no se puede usar para registrarte de '
          'nuevo. Tus pedidos se conservan. Para reactivarla tenés que '
          'contactar a tu distribuidora.',
      primaryLabel: 'Eliminar cuenta',
      secondaryLabel: 'Cancelar',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await model.deleteAccount();
    if (!deleted && context.mounted && model.deleteError != null) {
      await showSplgDialog(
        context,
        title: 'No pudimos eliminar tu cuenta',
        message: model.deleteError!,
        illustration: SplgIllustration.error,
      );
    }
  }
}

/// Cambiar o quitar la foto de perfil.
class _PhotoActions extends StatelessWidget {
  const _PhotoActions({required this.model});

  final ProfileViewModel model;

  @override
  Widget build(BuildContext context) {
    final working = model.busy('photo');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('profile-photo-change'),
              onPressed: working ? null : () => _choose(context),
              icon: working
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(AppIcons.camera, size: 18),
              label: Text(model.hasPhoto ? 'Cambiar foto' : 'Agregar foto'),
            ),
            if (model.hasPhoto)
              TextButton(
                key: const Key('profile-photo-remove'),
                onPressed: working ? null : model.removePhoto,
                child: const Text('Quitar'),
              ),
          ],
        ),
        if (model.photoError != null)
          Text(model.photoError!,
              key: const Key('profile-photo-error'),
              textAlign: TextAlign.center,
              style: SplgType.of(context)
                  .caption
                  .copyWith(color: context.brasa.danger)),
      ],
    );
  }

  Future<void> _choose(BuildContext context) async {
    final source = await choosePhotoSource(context);
    if (source != null) await model.changePhoto(source);
  }
}
