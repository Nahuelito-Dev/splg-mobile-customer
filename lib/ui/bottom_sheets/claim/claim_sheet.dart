import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/services/photo_picker.dart';
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
    final type = SplgType.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SplgBottomPanel(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hacer un reclamo', style: type.heading),
              const SizedBox(height: 4),
              Text('Contanos qué pasó con este pedido y lo revisamos.',
                  style: type.caption),
              const SizedBox(height: 12),
              for (final r in kClaimReasons)
                SplgRadioRow(
                  key: Key('claim-reason-$r'),
                  title: r,
                  selected: r == viewModel.reason,
                  onTap: viewModel.isBusy ? null : () => viewModel.setReason(r),
                ),
              const SizedBox(height: 12),
              SplgTextArea(
                controller: viewModel.descriptionController,
                hint: 'Contá brevemente qué pasó',
                maxLength: 300,
                minLines: 3,
                enabled: !viewModel.isBusy,
              ),
              const SizedBox(height: 12),
              if (viewModel.photo == null)
                Row(
                  children: [
                    Expanded(
                      child: SplgButton(
                        key: const Key('claim-photo-camera'),
                        title: 'Sacar foto',
                        style: SplgButtonStyle.outlined,
                        onPressed: viewModel.isBusy || viewModel.processingPhoto
                            ? null
                            : () => viewModel.attach(PhotoSource.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SplgButton(
                        key: const Key('claim-photo-gallery'),
                        title: 'Elegir de la galería',
                        style: SplgButtonStyle.outlined,
                        onPressed: viewModel.isBusy || viewModel.processingPhoto
                            ? null
                            : () => viewModel.attach(PhotoSource.gallery),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(viewModel.photo!.bytes,
                          key: const Key('claim-photo-preview'),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Foto adjunta', style: type.body)),
                    TextButton(
                      key: const Key('claim-photo-remove'),
                      onPressed:
                          viewModel.isBusy ? null : viewModel.removePhoto,
                      child: const Text('Quitar'),
                    ),
                  ],
                ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(viewModel.errorMessage!,
                      key: const Key('claim-error'),
                      style: type.body.copyWith(color: context.brasa.danger)),
                ),
              const SizedBox(height: 16),
              SplgButton(
                title: 'Enviar reclamo',
                loading: viewModel.isBusy,
                onPressed: viewModel.processingPhoto
                    ? null
                    : () async {
                        final ok = await viewModel.submit(orderId);
                        if (ok) {
                          completer?.call(SheetResponse(
                              confirmed: true, data: viewModel.photoWarning));
                        }
                      },
              ),
              const SizedBox(height: 8),
              SplgButton(
                title: 'Cancelar',
                style: SplgButtonStyle.outlined,
                onPressed: viewModel.isBusy
                    ? null
                    : () => completer?.call(SheetResponse(confirmed: false)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  ClaimSheetModel viewModelBuilder(BuildContext context) => ClaimSheetModel();
}
