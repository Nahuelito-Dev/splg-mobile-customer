import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'delivery_code_sheet_model.dart';

/// Hoja para tipear el código de entrega del chofer. `request.data` trae
/// `{ orderId }`. Completa con `SheetResponse(confirmed: true)` cuando el back
/// confirmó la entrega.
class DeliveryCodeSheet extends StackedView<DeliveryCodeSheetModel> {
  final Function(SheetResponse)? completer;
  final SheetRequest request;

  const DeliveryCodeSheet({
    super.key,
    required this.completer,
    required this.request,
  });

  @override
  Widget builder(
    BuildContext context,
    DeliveryCodeSheetModel viewModel,
    Widget? child,
  ) {
    final type = SplgType.of(context);
    final busy = viewModel.isBusy;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SplgBottomPanel(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ingresar el código', style: type.heading),
              const SizedBox(height: 4),
              Text(
                  'Escribí el código que el repartidor te muestra debajo del QR.',
                  style: type.caption),
              const SizedBox(height: 12),
              SplgTextField(
                key: const Key('delivery-code-field'),
                controller: viewModel.codeController,
                hint: 'Ej.: 482913',
                enabled: !busy,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  const _UpperCaseFormatter(),
                  LengthLimitingTextInputFormatter(
                      DeliveryCodeSheetModel.maxLength),
                ],
                onSubmitted: (_) => _submit(viewModel),
              ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(viewModel.errorMessage!,
                      key: const Key('delivery-code-error'),
                      style: type.body.copyWith(color: context.brasa.danger)),
                ),
              const SizedBox(height: 16),
              SplgButton(
                key: const Key('delivery-code-confirm'),
                title: 'Confirmar entrega',
                loading: busy,
                onPressed: () => _submit(viewModel),
              ),
              const SizedBox(height: 8),
              SplgButton(
                title: 'Cancelar',
                style: SplgButtonStyle.outlined,
                onPressed: busy
                    ? null
                    : () => completer?.call(SheetResponse(confirmed: false)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(DeliveryCodeSheetModel viewModel) async {
    if (await viewModel.submit()) {
      completer?.call(SheetResponse(confirmed: true));
    } else if (viewModel.sessionExpired) {
      completer?.call(SheetResponse(confirmed: false));
    }
  }

  @override
  DeliveryCodeSheetModel viewModelBuilder(BuildContext context) {
    final data = request.data;
    final orderId = data is Map ? data['orderId']?.toString() ?? '' : '';
    return DeliveryCodeSheetModel(orderId: orderId);
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
