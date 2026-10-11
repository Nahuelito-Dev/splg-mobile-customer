import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'rate_driver_sheet_model.dart';

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
              Text('Calificá al repartidor', style: type.heading),
              const SizedBox(height: 4),
              Text(subtitle, style: type.caption),
              const SizedBox(height: 8),
              SplgRatingInput(
                value: viewModel.stars,
                enabled: !viewModel.isBusy,
                onChanged: viewModel.setStars,
              ),
              const SizedBox(height: 8),
              SplgTextArea(
                controller: viewModel.commentController,
                hint: 'Comentario (opcional)',
                maxLength: 300,
                minLines: 3,
                enabled: !viewModel.isBusy,
              ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(viewModel.errorMessage!,
                      key: const Key('rate-error'),
                      style: type.body.copyWith(color: context.brasa.danger)),
                ),
              const SizedBox(height: 16),
              SplgButton(
                title: 'Enviar',
                loading: viewModel.isBusy,
                onPressed: () async {
                  final ok = await viewModel.submit(orderId);
                  if (ok) completer?.call(SheetResponse(confirmed: true));
                },
              ),
              const SizedBox(height: 8),
              SplgButton(
                title: 'Omitir',
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
  RateDriverSheetModel viewModelBuilder(BuildContext context) =>
      RateDriverSheetModel();
}
