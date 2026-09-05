import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';

/// Pantalla de escaneo del QR que muestra el chofer al llegar. El QR trae
/// EXACTAMENTE el `deliveryCode` (string plano, no JSON), asi que lo leido
/// se manda tal cual como `code` a `POST /orders/:id/confirm-delivery`.
class QrScanViewModel extends BaseViewModel {
  QrScanViewModel({required this.orderId});

  final String orderId;

  final _customerService = locator<CustomerService>();
  final _trackingService = locator<OrderTrackingService>();
  final _dialogService = locator<DialogService>();
  final _navigationService = locator<NavigationService>();

  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Se dispara con cada frame donde el scanner detecta un codigo. Frenamos
  /// la camara mientras confirmamos con el backend para no reprocesar el
  /// mismo QR ni disparar dos requests en paralelo.
  // TODO: hoy tomamos el primer codigo leido sin validar que sea el de ESTE
  // pedido antes de mandarlo (esa validacion la hace el backend contra
  // order.deliveryCode y devuelve 400 si no matchea). Si el cliente llegara a
  // tener mas de un pedido on_the_way a la vez, un 400 no distingue "codigo
  // de otro pedido" de "codigo mal escrito" — UX a revisar si se da ese caso.
  Future<void> onDetect(BarcodeCapture capture) async {
    if (_isProcessing) {
      return;
    }

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );
    if (code == null) {
      return;
    }

    _isProcessing = true;
    rebuildUi();
    await controller.stop();

    final token = await _customerService.token;
    if (token == null) {
      await _dialogService.showDialog(
        title: 'Sesion expirada',
        description: 'Volve a iniciar sesion para confirmar la entrega.',
      );
      _navigationService.back(result: false);
      return;
    }

    final result = await _trackingService.confirmDelivery(
      orderId,
      code,
      token,
    );

    if (result == ConfirmDeliveryResult.success) {
      await _dialogService.showDialog(
        title: '¡Entrega confirmada!',
        description: 'Gracias por tu compra.',
      );
      _navigationService.back(result: true);
      return;
    }

    await _dialogService.showDialog(
      title: result == ConfirmDeliveryResult.invalidCode
          ? 'Codigo invalido'
          : 'No se pudo confirmar',
      description: result == ConfirmDeliveryResult.invalidCode
          ? 'El codigo escaneado no es valido o el pedido no esta en camino.'
          : 'Revisa tu conexion e intenta nuevamente.',
    );

    _isProcessing = false;
    rebuildUi();
    await controller.start();
  }

  Future<void> retryCamera() async {
    await controller.start();
  }

  void cancel() {
    _navigationService.back(result: false);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
