import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'market_model.dart';

class Market extends StackedView<MarketModel> {
  const Market({super.key});

  @override
  Widget builder(
    BuildContext context,
    MarketModel viewModel,
    Widget? child,
  ) {
    return const SizedBox.shrink();
  }

  @override
  MarketModel viewModelBuilder(
    BuildContext context,
  ) =>
      MarketModel();
}
