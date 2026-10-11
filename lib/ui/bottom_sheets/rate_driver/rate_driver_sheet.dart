import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/ui/common/ui_helpers.dart';

import 'rate_driver_sheet_model.dart';
import 'package:splg_lib/theme/app_colors.dart';
import 'package:splg_lib/theme/brasa_palette.dart';

/// Hoja para calificar al chofer tras la entrega. `request.data` trae
/// `{ orderId, driverName }`. Completa con `SheetResponse(confirmed: true)` si
/// se envió la calificación, o `false` si se omite.
class RateDriverSheet extends StackedView<RateDriverSheetModel> {
  final Function(SheetResponse)? completer;
  final SheetRequest request;

  const RateDriverSheet({
    Key? key,
    required this.completer,
    required this.request,
  }) : super(key: key);

  @override
  Widget builder(
    BuildContext context,
    RateDriverSheetModel viewModel,
    Widget? child,
  ) {
    final data = (request.data is Map)
        ? Map<String, dynamic>.from(request.data as Map)
        : <String, dynamic>{};
    final orderId = data['orderId']?.toString() ?? '';
    final driverName = data['driverName']?.toString();
    final subtitle = (driverName != null && driverName.trim().isNotEmpty)
        ? '¿Cómo estuvo la entrega de $driverName?'
        : '¿Cómo estuvo la entrega?';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calificá al chofer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            verticalSpaceTiny,
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: context.brasa.muted),
            ),
            verticalSpaceMedium,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  iconSize: 40,
                  onPressed:
                      viewModel.isBusy ? null : () => viewModel.setStars(value),
                  icon: Icon(
                    value <= viewModel.stars ? Icons.star : Icons.star_border,
                    color: AppColors.gas400,
                  ),
                );
              }),
            ),
            verticalSpaceSmall,
            TextField(
              controller: viewModel.commentController,
              enabled: !viewModel.isBusy,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (viewModel.errorMessage != null) ...[
              verticalSpaceSmall,
              Text(
                viewModel.errorMessage!,
                style: TextStyle(color: context.brasa.danger, fontSize: 13),
              ),
            ],
            verticalSpaceMedium,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: viewModel.isBusy
                        ? null
                        : () =>
                            completer?.call(SheetResponse(confirmed: false)),
                    child: const Text('Omitir'),
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
                        : const Text('Enviar'),
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
  RateDriverSheetModel viewModelBuilder(BuildContext context) =>
      RateDriverSheetModel();
}
