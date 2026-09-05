import 'package:flutter/material.dart';

import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/ui/common/ui_helpers.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Mis Direcciones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          verticalSpaceMedium,
          if (viewModel.addresses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No tienes direcciones guardadas'),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: viewModel.addresses.length,
                separatorBuilder: (context, index) => Divider(
                  color: Theme.of(context).colorScheme.outline.withAlpha(20),
                ),
                itemBuilder: (context, index) {
                  final address = viewModel.addresses[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(address.streetName),
                    subtitle: Text(address.city ?? 'Sin ciudad'),
                    onTap: () {
                      if (completer != null) {
                        viewModel.selectAddress(address, completer!);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  AddressListSheetModel viewModelBuilder(BuildContext context) =>
      AddressListSheetModel();
}
