import 'dart:developer';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_customer/ui/bottom_sheets/delivery_code/delivery_code_sheet_model.dart';
import 'package:splg_lib/permissions/app_permission.dart';

/// Pantalla de escaneo del QR que muestra el chofer al llegar. El QR trae
/// EXACTAMENTE el `deliveryCode` (string plano, no JSON), asi que lo leido
/// se manda tal cual como `code` a `POST /orders/:id/confirm-delivery`.
class QrScanViewModel extends BaseViewModel {
  QrScanViewModel({required this.orderId, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final String orderId;
  final DateTime Function() _now;

  /// Cuánto se ignora una lectura que ya se rechazó (la cámara sigue apuntando al mismo QR).
  static const repeatedReadingWindow = Duration(seconds: 4);

  String? _lastRejected;
  DateTime? _lastRejectedAt;

  final _customerService = locator<CustomerService>();
  final _trackingService = locator<OrderTrackingService>();
  final _dialogService = locator<DialogService>();
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();

  final _permissions = locator<AppPermissions>();

  // No arranca solo: la cámara se enciende recién cuando el permiso está
  // concedido (si no, el SDK lo pediría sin explicación previa).
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );

  /// null = todavía consultando/pidiendo el permiso de cámara.
  PermissionOutcome? _camera;
  PermissionOutcome? get cameraOutcome => _camera;

  bool get cameraGranted => _camera?.isGranted ?? false;
  bool get cameraNeedsSettings =>
      _camera == PermissionOutcome.permanentlyDenied;

  Future<void> initialize() => _requestCamera();

  Future<void> _requestCamera() async {
    _camera = null;
    rebuildUi();
    _camera = await _permissions.ensure(AppPermission.camera);
    rebuildUi();
    if (cameraGranted) {
      await _startCamera();
    }
  }

  /// Enciende la cámara; si el plugin falla, el error lo muestra el
  /// `errorBuilder` del scanner en vez de romper la pantalla.
  Future<void> _startCamera() async {
    try {
      await controller.start();
    } catch (e) {
      log('QrScanViewModel: no se pudo abrir la cámara: $e');
    }
  }

  Future<void> openSettings() => _permissions.openSettings();

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Se dispara con cada frame donde el scanner detecta un codigo. Frenamos
  /// la camara mientras confirmamos con el backend para no reprocesar el
  /// mismo QR ni disparar dos requests en paralelo. Antes de mandar nada se
  /// descarta lo que no tiene forma plausible de codigo (URLs, texto largo); el
  /// formato exacto lo decide el back; una lectura que ya
  /// se rechazo se ignora un rato. Si el back dice que es el codigo de otro
  /// pedido, se le explica al cliente en vez de un "invalido" generico.
  Future<void> onDetect(BarcodeCapture capture) async {
    if (_isProcessing) {
      return;
    }

    final readings = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    if (readings.isEmpty) {
      return;
    }
    final code = readings
        .map(DeliveryCodeSheetModel.normalize)
        .firstWhere(DeliveryCodeSheetModel.isPlausible, orElse: () => '');

    if (code.isEmpty) {
      if (_isRepeatedRejection(readings.first)) return;
      await _rejectUnreadable(readings.first);
      return;
    }
    if (_isRepeatedRejection(code)) {
      return;
    }

    _isProcessing = true;
    rebuildUi();
    await controller.stop();

    final token = await _customerService.token;
    if (token == null) {
      await _dialogService.showDialog(
        title: 'Tu sesión venció',
        description: 'Volvé a iniciar sesión para confirmar la entrega.',
      );
      _navigationService.back(result: false);
      return;
    }

    final outcome = await _trackingService.confirmDelivery(
      orderId,
      code,
      token,
    );

    if (outcome.isSuccess) {
      await _dialogService.showDialog(
        title: '¡Entrega confirmada!',
        description: 'Gracias por tu compra.',
      );
      _navigationService.back(result: true);
      return;
    }

    // El 401 ya lo atiende `SessionService.expire` (avisa y lleva al login):
    // acá no se muestra otro diálogo ni se vuelve atrás.
    if (outcome.result == ConfirmDeliveryResult.sessionExpired) return;

    final rejectsCode = const {
      ConfirmDeliveryResult.invalidCode,
      ConfirmDeliveryResult.otherOrder,
      ConfirmDeliveryResult.malformedCode,
      ConfirmDeliveryResult.blocked,
    }.contains(outcome.result);
    await _dialogService.showDialog(
      title: switch (outcome.result) {
        ConfirmDeliveryResult.invalidCode => 'Código inválido',
        ConfirmDeliveryResult.otherOrder => 'Es el QR de otro pedido',
        ConfirmDeliveryResult.malformedCode => 'No pudimos leer el código',
        ConfirmDeliveryResult.blocked => 'Código bloqueado',
        _ => 'No se pudo confirmar',
      },
      description:
          outcome.message ?? 'No pudimos confirmar la entrega. Probá de nuevo.',
    );

    if (rejectsCode) _remember(code);
    _isProcessing = false;
    rebuildUi();
    await _startCamera();
  }

  bool _isRepeatedRejection(String reading) =>
      reading == _lastRejected &&
      _lastRejectedAt != null &&
      _now().difference(_lastRejectedAt!) < repeatedReadingWindow;

  void _remember(String reading) {
    _lastRejected = reading;
    _lastRejectedAt = _now();
  }

  /// Lo leido no tiene forma de codigo de entrega (otro QR, o un frame mal
  /// leido): no se manda al back.
  Future<void> _rejectUnreadable(String reading) async {
    _isProcessing = true;
    rebuildUi();
    await controller.stop();
    await _dialogService.showDialog(
      title: 'No pudimos leer el código',
      description: OrderTrackingService.malformedCodeText,
    );
    _remember(reading);
    _isProcessing = false;
    rebuildUi();
    await _startCamera();
  }

  /// "Reintentar": si el permiso no está, lo vuelve a pedir; si está, reabre
  /// la cámara.
  Future<void> retryCamera() async {
    if (cameraGranted) {
      await _startCamera();
    } else {
      await _requestCamera();
    }
  }

  /// Alternativa al QR (cámara rota, sin permiso, simulador): el cliente tipea
  /// el código que el chofer muestra debajo del QR. La hoja confirma contra el
  /// mismo endpoint y muestra ahí los rechazos del back.
  Future<void> enterCodeManually() async {
    if (_isProcessing) return;
    final response = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.deliveryCode,
      isScrollControlled: true,
      data: {'orderId': orderId},
    );
    if (response?.confirmed != true) return;
    await _dialogService.showDialog(
      title: '¡Entrega confirmada!',
      description: 'Gracias por tu compra.',
    );
    _navigationService.back(result: true);
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
