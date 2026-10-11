import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stacked/stacked.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Escanear QR de entrega'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: viewModel.cancel,
        ),
        actions: [
          if (viewModel.cameraGranted)
            IconButton(
              icon: const Icon(Icons.flash_on),
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
                  ),
                ),
                const _ScanWindowOverlay(),
                const SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40, left: 24, right: 24),
                      child: Text(
                        'Apunta la camara al codigo QR que te muestra el chofer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (viewModel.isProcessing)
                  Container(
                    color: Colors.black.withAlpha(180),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Confirmando entrega...',
                            style: TextStyle(color: Colors.white),
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
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
              const Icon(Icons.no_photography, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                viewModel.cameraNeedsSettings
                    ? 'La cámara está desactivada para SPLG. Activala desde Ajustes para escanear el QR de la entrega.'
                    : 'Necesitamos la cámara para escanear el QR de la entrega.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: viewModel.cameraNeedsSettings
                    ? viewModel.openSettings
                    : viewModel.retryCamera,
                child: Text(
                  viewModel.cameraNeedsSettings
                      ? 'Abrir Ajustes'
                      : 'Reintentar',
                ),
              ),
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
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

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
              const Icon(Icons.no_photography, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                isPermissionDenied
                    ? 'No tenes permiso de camara. Activalo desde Ajustes para poder escanear el QR.'
                    : 'No se pudo abrir la camara. Intenta de nuevo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isPermissionDenied ? onSettings : onRetry,
                child:
                    Text(isPermissionDenied ? 'Abrir Ajustes' : 'Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
