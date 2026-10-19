import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/app_info.dart';

import 'package:splg_customer/ui/widgets/app_header.dart';
import 'personal_info_viewmodel.dart';

/// Datos de la cuenta, sólo lectura (se editan desde "Editar perfil").
class PersonalInfoView extends StackedView<PersonalInfoViewModel> {
  const PersonalInfoView({super.key});

  @override
  PersonalInfoViewModel viewModelBuilder(BuildContext context) =>
      PersonalInfoViewModel();

  @override
  Widget builder(
      BuildContext context, PersonalInfoViewModel model, Widget? child) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final c = model.customer;
    return Scaffold(
      appBar:
          const AppHeader(title: 'Información personal', centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registro', style: type.subtitle),
              Divider(
                  color: brasa.primaryStrong.withValues(alpha: 0.35),
                  height: 30),
              AppInfoSection(
                icon: SplgIcons.user,
                title: 'Datos personales',
                rows: [
                  AppInfoRow(title: 'Nombre y apellido:', value: c.fullName)
                ],
              ),
              AppInfoSection(
                icon: SplgIcons.phone,
                title: 'Información de contacto',
                rows: [
                  AppInfoRow(title: 'Número de teléfono:', value: c.phoneNumber)
                ],
              ),
              AppInfoSection(
                icon: SplgIcons.mail,
                title: 'Información de la cuenta',
                rows: [
                  AppInfoRow(title: 'Correo electrónico:', value: c.email),
                  AppInfoRow(title: 'Domicilio:', value: model.primaryAddress),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
