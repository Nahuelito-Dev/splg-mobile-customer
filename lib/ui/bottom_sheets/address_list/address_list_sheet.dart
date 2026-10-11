import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'address_list_sheet_model.dart';

class AddressListSheet extends StackedView<AddressListSheetModel> {
  final Function(SheetResponse response)? completer;
  final SheetRequest request;
  const AddressListSheet({
    super.key,
    required this.completer,
    required this.request,
  });

  @override
  Widget builder(
    BuildContext context,
    AddressListSheetModel viewModel,
    Widget? child,
  ) {
    final type = SplgType.of(context);
    final data = request.data;
    final selectedId = data is Map ? data['selectedId']?.toString() : null;
    return SplgBottomPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Mis direcciones', style: type.heading),
          const SizedBox(height: 12),
          if (viewModel.addresses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: Text('Todavía no tenés direcciones guardadas.')),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in viewModel.addresses)
                    SplgRadioRow(
                      key: Key('sheet-address-${a.addressId}'),
                      icon: SplgIcons.location,
                      title: a.streetName,
                      subtitle: a.city,
                      selected: viewModel.isSelected(a, selectedId),
                      onTap: () {
                        if (completer != null) {
                          viewModel.selectAddress(a, completer!);
                        }
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SplgButton(
            key: const Key('sheet-add-address'),
            title: 'Agregar dirección',
            style: SplgButtonStyle.outlined,
            onPressed: completer == null
                ? null
                : () => viewModel.addAddress(completer!),
          ),
        ],
      ),
    );
  }

  @override
  AddressListSheetModel viewModelBuilder(BuildContext context) =>
      AddressListSheetModel();
}
