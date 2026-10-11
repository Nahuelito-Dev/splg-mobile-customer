import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/app_header.dart';
import 'edit_profile_viewmodel.dart';

class EditProfileView extends StackedView<EditProfileViewModel> {
  const EditProfileView({super.key});

  @override
  EditProfileViewModel viewModelBuilder(BuildContext context) =>
      EditProfileViewModel();

  @override
  Widget builder(
      BuildContext context, EditProfileViewModel model, Widget? child) {
    final type = SplgType.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t, style: type.label.copyWith(fontSize: context.sp(11))),
        );
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: const AppHeader(
            title: 'Editar perfil', centerTitle: false, bell: false),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label('Nombre y apellido'),
                      SplgTextField(
                        key: const Key('edit-name'),
                        controller: model.name,
                        enabled: !model.isBusy,
                        errorText: model.nameError,
                        textInputAction: TextInputAction.next,
                      ),
                      label('Teléfono'),
                      SplgPhoneField(
                        key: const Key('edit-phone'),
                        controller: model.phone,
                        enabled: !model.isBusy,
                        errorText: model.phoneError,
                      ),
                      if (model.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(model.errorMessage!,
                              key: const Key('edit-error'),
                              style: type.body
                                  .copyWith(color: context.brasa.danger)),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SplgButton(
                  title: 'Guardar',
                  loading: model.isBusy,
                  onPressed: model.save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
