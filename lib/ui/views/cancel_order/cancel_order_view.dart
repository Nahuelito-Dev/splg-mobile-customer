import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/widgets/app_header.dart';
import 'cancel_order_viewmodel.dart';

class CancelOrderView extends StackedView<CancelOrderViewModel> {
  const CancelOrderView({super.key, required this.orderId});

  final String orderId;

  @override
  CancelOrderViewModel viewModelBuilder(BuildContext context) =>
      CancelOrderViewModel(orderId: orderId);

  @override
  Widget builder(
      BuildContext context, CancelOrderViewModel model, Widget? child) {
    final type = SplgType.of(context);
    return PopScope(
      canPop: !model.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) model.close();
      },
      child: Scaffold(
        appBar: const AppHeader(title: 'Cancelar pedido', bell: false),
        body: SafeArea(
          child: model.done
              ? Column(
                  children: [
                    const Expanded(
                      child: SplgEmptyState(
                        illustration: SplgIllustration.success,
                        title: 'Pedido cancelado',
                        message: 'Tu pedido quedó cancelado.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child:
                          SplgButton(title: 'Volver', onPressed: model.close),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('¿Por qué querés cancelar?',
                                style: type.subtitle),
                            const SizedBox(height: 10),
                            for (final r in kCancelReasons)
                              SplgRadioRow(
                                key: Key('reason-$r'),
                                title: r,
                                selected: model.reason == r,
                                onTap:
                                    model.isBusy ? null : () => model.select(r),
                              ),
                            if (model.isOther)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SplgTextArea(
                                  controller: model.other,
                                  hint: 'Contanos el motivo',
                                  maxLength: 300,
                                  minLines: 3,
                                  enabled: !model.isBusy,
                                ),
                              ),
                            if (model.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(model.errorMessage!,
                                    key: const Key('cancel-error'),
                                    style: type.body
                                        .copyWith(color: context.brasa.danger)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SplgButton(
                            title: model.errorMessage != null
                                ? 'Reintentar'
                                : 'Confirmar cancelación',
                            style: SplgButtonStyle.danger,
                            loading: model.isBusy,
                            onPressed: model.canSubmit ? model.submit : null,
                          ),
                          const SizedBox(height: 8),
                          SplgButton(
                            title: 'Volver',
                            style: SplgButtonStyle.outlined,
                            onPressed: model.isBusy ? null : model.close,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
