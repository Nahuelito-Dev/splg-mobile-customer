import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/domain/order_receiver.dart';
import 'receiver_sheet_model.dart';

/// Hoja para indicar quién recibe el pedido. `request.data` trae
/// `{ orderId?, receiver? }`: con `orderId` guarda en ese pedido; `receiver`
/// precarga lo ya indicado. Completa con `SheetResponse(confirmed: true, data:
/// OrderReceiver)`.
class ReceiverSheet extends StackedView<ReceiverSheetModel> {
  final Function(SheetResponse)? completer;
  final SheetRequest request;

  const ReceiverSheet({
    super.key,
    required this.completer,
    required this.request,
  });

  Map<String, dynamic> get _data => (request.data is Map)
      ? Map<String, dynamic>.from(request.data as Map)
      : <String, dynamic>{};

  @override
  Widget builder(
    BuildContext context,
    ReceiverSheetModel viewModel,
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
              Text('¿Quién recibe el pedido?', style: type.heading),
              const SizedBox(height: 4),
              Text(
                  'Si no vas a estar, indicá quién lo recibe. Estos datos los '
                  've el repartidor y se borran al vencer el plazo de reclamo.',
                  style: type.caption),
              const SizedBox(height: 12),
              SplgTextField(
                key: const Key('receiver-name'),
                controller: viewModel.nameController,
                hint: 'Nombre y apellido',
                enabled: !busy,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              SplgTextField(
                key: const Key('receiver-document'),
                controller: viewModel.documentController,
                hint: 'Documento (DNI, CUIT/CUIL o pasaporte)',
                enabled: !busy,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              SplgTextField(
                key: const Key('receiver-relationship'),
                controller: viewModel.relationshipController,
                hint: 'Relación (familiar, vecino, encargado...)',
                enabled: !busy,
                textInputAction: TextInputAction.done,
              ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(viewModel.errorMessage!,
                      key: const Key('receiver-error'),
                      style: type.body.copyWith(color: context.brasa.danger)),
                ),
              const SizedBox(height: 16),
              SplgButton(
                key: const Key('receiver-save'),
                title: 'Guardar',
                loading: busy,
                onPressed: () async {
                  if (await viewModel.submit()) {
                    completer?.call(
                        SheetResponse(confirmed: true, data: viewModel.result));
                  }
                },
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

  @override
  ReceiverSheetModel viewModelBuilder(BuildContext context) {
    final data = _data;
    final receiver = data['receiver'];
    return ReceiverSheetModel(
      orderId: data['orderId']?.toString(),
      initial: receiver is OrderReceiver ? receiver : null,
    );
  }
}
