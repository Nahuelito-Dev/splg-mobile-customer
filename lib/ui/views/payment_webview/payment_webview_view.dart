import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'payment_webview_viewmodel.dart';

class PaymentWebViewView extends StackedView<PaymentWebViewModel> {
  const PaymentWebViewView({
    super.key,
    required this.paymentUrl,
  });

  final String paymentUrl;

  @override
  Widget builder(
    BuildContext context,
    PaymentWebViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: SplgHeader(
        title: 'Pago con Mercado Pago',
        onBack: viewModel.cancel,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: viewModel.controller),
            if (viewModel.isPageLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  @override
  void onViewModelReady(PaymentWebViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }

  @override
  PaymentWebViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      PaymentWebViewModel(paymentUrl: paymentUrl);
}
