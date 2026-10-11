import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/app_header.dart';
import 'address_form_viewmodel.dart';

class AddressFormView extends StackedView<AddressFormViewModel> {
  const AddressFormView({super.key, this.address});

  /// Si viene, es una edición.
  final Address? address;

  @override
  AddressFormViewModel viewModelBuilder(BuildContext context) =>
      AddressFormViewModel(address: address);

  @override
  Widget builder(
      BuildContext context, AddressFormViewModel model, Widget? child) {
    final type = SplgType.of(context);

    Widget field(String label, Widget f) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(label,
                    style: type.label.copyWith(fontSize: context.sp(11))),
              ),
              f,
            ],
          ),
        );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppHeader(
            title: model.isEditing ? 'Editar dirección' : 'Nueva dirección',
            bell: false),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      field(
                        'Calle',
                        SplgTextField(
                          key: const Key('addr-street'),
                          controller: model.street,
                          enabled: !model.isBusy,
                          hint: 'Ej: Av. Mitre',
                          errorText: model.streetError,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      field(
                        'Número',
                        SplgTextField(
                          key: const Key('addr-number'),
                          controller: model.number,
                          enabled: !model.isBusy,
                          hint: 'Ej: 1234',
                          errorText: model.numberError,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      field(
                        'Localidad',
                        SplgTextField(
                          key: const Key('addr-city'),
                          controller: model.city,
                          enabled: !model.isBusy,
                          hint: 'Ej: Posadas',
                          errorText: model.cityError,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      field(
                        'Referencia (opcional)',
                        SplgTextField(
                          key: const Key('addr-reference'),
                          controller: model.reference,
                          enabled: !model.isBusy,
                          hint: 'Ej: Piso 3 B, tocar timbre',
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      Text(
                          'Ubicamos tu dirección con el mapa del teléfono para '
                          'que el repartidor llegue.',
                          style: type.caption),
                      if (model.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(model.errorMessage!,
                              key: const Key('addr-error'),
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
