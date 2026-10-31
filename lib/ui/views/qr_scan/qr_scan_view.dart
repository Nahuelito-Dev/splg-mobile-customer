import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:splg_lib/splg_lib.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/ui/common/app_icons.dart';
import 'qr_scan_viewmodel.dart';

class QrScanView extends StackedView<QrScanViewModel> {
  const QrScanView({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  Widget builder(
    BuildContext context,
    QrScanViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: SplgHeader(
        title: 'Escanear QR de entrega',
        onGradient: true,
        onBack: viewModel.cancel,
        actions: [
          if (viewModel.cameraGranted)
            IconButton(
              tooltip: 'Linterna',
              icon: const Icon(SplgIcons.online, color: Colors.white),
              onPressed: viewModel.controller.toggleTorch,
            ),
        ],
      ),
      body: !viewModel.cameraGranted
          ? _CameraGate(viewModel: viewModel)
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: viewModel.controller,
                  onDetect: viewModel.onDetect,
                  errorBuilder: (context, error) => _ScannerError(
                    error: error,
                    onRetry: viewModel.retryCamera,
                    onSettings: viewModel.openSettings,
                    onManualCode: viewModel.enterCodeManually,
                  ),
                ),
                // Con la cámara caída el aviso de error ya trae sus botones: el
                // marco y la ayuda del QR sobrarían y se superponen.
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: viewModel.controller,
                  builder: (context, state, _) => state.error != null
                      ? const SizedBox.shrink()
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            const _ScanWindowOverlay(),
                            SafeArea(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 24, left: 24, right: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Apuntá la cámara al código QR que te muestra el repartidor',
                                        textAlign: TextAlign.center,
                                        style: SplgType.of(context)
                                            .subtitle
                                            .copyWith(color: Colors.white),
                                      ),
                                      const SizedBox(height: 16),
                                      _ManualCodeButton(
                                          onPressed:
                                              viewModel.enterCodeManually),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (viewModel.isProcessing)
                  Container(
                    color: Colors.black.withAlpha(180),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SplgLoader(onDark: true),
                          const SizedBox(height: 12),
                          Text(
                            'Confirmando la entrega...',
                            style: SplgType.of(context)
                                .body
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  QrScanViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      QrScanViewModel(orderId: orderId);

  @override
  void onViewModelReady(QrScanViewModel viewModel) {
    viewModel.initialize();
    super.onViewModelReady(viewModel);
  }
}

/// Mientras se consulta el permiso de cámara, o si no se concedió: nunca una
/// pantalla en blanco, siempre el motivo y qué hacer.
class _CameraGate extends StatelessWidget {
  const _CameraGate({required this.viewModel});

  final QrScanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.cameraOutcome == null) {
      return const ColoredBox(
        color: Colors.black,
        child: SplgLoader(onDark: true),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.cameraSlash, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                viewModel.cameraNeedsSettings
                    ? 'La cámara está desactivada para SPLG. Activala desde Ajustes para escanear el QR de la entrega.'
                    : 'Necesitamos la cámara para escanear el QR de la entrega.',
                textAlign: TextAlign.center,
                style: SplgType.of(context).body.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              SplgButton(
                title: viewModel.cameraNeedsSettings
                    ? 'Abrir Ajustes'
                    : 'Reintentar',
                style: SplgButtonStyle.white,
                expand: false,
                onPressed: viewModel.cameraNeedsSettings
                    ? viewModel.openSettings
                    : viewModel.retryCamera,
              ),
              const SizedBox(height: 12),
              _ManualCodeButton(onPressed: viewModel.enterCodeManually),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marco cuadrado centrado, solo decorativo: indica al usuario donde encuadrar
/// el QR. mobile_scanner no requiere que el QR este exactamente ahi dentro.
class _ScanWindowOverlay extends StatelessWidget {
  const _ScanWindowOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.error,
    required this.onRetry,
    required this.onSettings,
    required this.onManualCode,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onSettings;
  final VoidCallback onManualCode;

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.cameraSlash, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                isPermissionDenied
                    ? 'No tenés permiso para usar la cámara. Activalo desde Ajustes para poder escanear el QR.'
                    : 'No se pudo abrir la cámara. Probá de nuevo.',
                textAlign: TextAlign.center,
                style: SplgType.of(context).body.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              SplgButton(
                title: isPermissionDenied ? 'Abrir Ajustes' : 'Reintentar',
                style: SplgButtonStyle.white,
                expand: false,
                onPressed: isPermissionDenied ? onSettings : onRetry,
              ),
              const SizedBox(height: 12),
              _ManualCodeButton(onPressed: onManualCode),
            ],
          ),
        ),
      ),
    );
  }
}

/// Salida cuando el QR no se puede leer: tipear el código que muestra el chofer.
class _ManualCodeButton extends StatelessWidget {
  const _ManualCodeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SplgButton(
        key: const Key('qr-manual-code'),
        title: 'Ingresar el código',
        style: SplgButtonStyle.white,
        expand: false,
        onPressed: onPressed,
      );
}
