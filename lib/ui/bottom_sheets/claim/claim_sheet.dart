import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:jennigas_customer/ui/common/app_colors.dart';
import 'package:jennigas_customer/ui/common/ui_helpers.dart';

import 'claim_sheet_model.dart';

/// Hoja para abrir un reclamo sobre un pedido. `request.data` trae
/// `{ orderId }`. Completa con `SheetResponse(confirmed: true)` si se envió.
class ClaimSheet extends StackedView<ClaimSheetModel> {
  final Function(SheetResponse)? completer;
  final SheetRequest request;

  const ClaimSheet({
    Key? key,
    required this.completer,
    required this.request,
  }) : super(key: key);

  @override
  Widget builder(
    BuildContext context,
    ClaimSheetModel viewModel,
    Widget? child,
  ) {
    final data = (request.data is Map)
        ? Map<String, dynamic>.from(request.data as Map)
        : <String, dynamic>{};
    final orderId = data['orderId']?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reportar un problema',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            verticalSpaceTiny,
            const Text(
              'Contanos qué pasó con este pedido y lo revisamos.',
              style: TextStyle(fontSize: 14, color: kcMediumGrey),
            ),
            verticalSpaceMedium,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kClaimReasons.map((reason) {
                final selected = reason == viewModel.reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: selected,
                  onSelected: viewModel.isBusy
                      ? null
                      : (_) => viewModel.setReason(reason),
                  selectedColor: kcPrimaryColor,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : kcMediumGrey,
                  ),
                );
              }).toList(),
            ),
            verticalSpaceMedium,
            TextField(
              controller: viewModel.descriptionController,
              enabled: !viewModel.isBusy,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Contá brevemente qué pasó',
                border: OutlineInputBorder(),
              ),
            ),
            if (viewModel.errorMessage != null) ...[
              verticalSpaceSmall,
              Text(
                viewModel.errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
            verticalSpaceMedium,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: viewModel.isBusy
                        ? null
                        : () => completer?.call(SheetResponse(confirmed: false)),
                    child: const Text('Cancelar'),
                  ),
                ),
                horizontalSpaceSmall,
                Expanded(
                  child: ElevatedButton(
                    onPressed: viewModel.isBusy
                        ? null
                        : () async {
                            final ok = await viewModel.submit(orderId);
                            if (ok) {
                              completer?.call(SheetResponse(confirmed: true));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: viewModel.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enviar reclamo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  ClaimSheetModel viewModelBuilder(BuildContext context) => ClaimSheetModel();
}
