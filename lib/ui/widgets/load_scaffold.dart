import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/ui/common/load_view_model.dart';
import 'package:splg_customer/ui/widgets/app_header.dart';

/// Pantalla interna con encabezado y los tres estados de una lectura:
/// cargando, error con "Reintentar" y contenido.
class LoadScaffold extends StatelessWidget {
  const LoadScaffold({
    super.key,
    required this.title,
    required this.model,
    required this.builder,
    this.centerTitle = true,
    this.bell = true,
    this.actions,
    this.floating,
  });

  final String title;
  final LoadViewModel model;
  final WidgetBuilder builder;
  final bool centerTitle;
  final bool bell;
  final List<Widget>? actions;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (model.isBusy) {
      body = const SplgLoader();
    } else if (model.loadError != null) {
      body = SplgEmptyState(
        illustration: model.loadError == ApiErrorText.offline
            ? SplgIllustration.noNetwork
            : SplgIllustration.error,
        title: model.loadError == ApiErrorText.offline
            ? 'Sin conexión'
            : 'No pudimos cargar',
        message: model.loadError!,
        action: model.canRetry
            ? SplgButton(
                title: 'Reintentar',
                style: SplgButtonStyle.outlined,
                expand: false,
                onPressed: model.load,
              )
            : SplgButton(
                key: const Key('load-back'),
                title: 'Volver',
                style: SplgButtonStyle.outlined,
                expand: false,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
      );
    } else {
      body = builder(context);
    }
    return Scaffold(
      appBar: AppHeader(
          title: title, centerTitle: centerTitle, bell: bell, actions: actions),
      floatingActionButton: floating,
      body: SafeArea(child: body),
    );
  }
}
