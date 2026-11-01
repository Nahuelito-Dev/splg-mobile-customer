import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/bank_details.dart';
import 'package:splg_customer/domain/transfer_receipt.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_customer/services/transfer_receipt_service.dart';

/// Estado del pago de un pedido por transferencia: datos bancarios, subida y
/// lista de comprobantes. Lo comparten el detalle y el seguimiento del pedido.
mixin TransferPayment on BaseViewModel {
  /// Lo que la pantalla sabe de su pedido.
  String get transferOrderId;
  bool get transferIsOnline;
  bool get transferCancelled;

  /// `paymentStatus` del back (`pending`, `failed`, `paid`...).
  String get transferPaymentStatus;

  /// Monto exacto que el cliente tiene que transferir: el total del pedido con
  /// el recargo por transferencia ya incluido, tal como lo guardó el back.
  double? get transferAmount;

  final _transfer = locator<TransferReceiptService>();
  final _dialogs = locator<DialogService>();

  /// Se reemplazan en los tests.
  ReceiptPicker picker = ReceiptPicker();
  Future<void> Function(String text) copyToClipboard =
      (text) => Clipboard.setData(ClipboardData(text: text));
  Future<bool> Function(Uri url) openUrl =
      (url) => launchUrl(url, mode: LaunchMode.externalApplication);

  /// Estado del pago para mostrar: «Pagado» si el back lo acreditó, «Comprobante
  /// en revisión» si hay comprobante y todavía no, «Pendiente de pago» si no.
  /// Null si el pedido no es por transferencia o está cancelado.
  String? get paymentStateLabel {
    if (!transferIsOnline || transferCancelled) return null;
    if (transferPaymentStatus == 'paid') return 'Pagado';
    if (receipts.isNotEmpty) return 'Comprobante en revisión';
    return 'Pendiente de pago';
  }

  /// Pedido por transferencia: se pueden ver los datos bancarios y subir el
  /// comprobante mientras el pago esté pendiente (o marcado como no recibido,
  /// que el comprobante sirve para corregir) y el pedido no se haya cancelado.
  bool get canPayByTransfer =>
      transferIsOnline &&
      !transferCancelled &&
      const {'pending', 'failed'}.contains(transferPaymentStatus);

  /// Datos bancarios del pedido; null hasta que se leen o si no se pudieron
  /// leer ([bankError]).
  BankDetails? bankDetails;
  String? bankError;

  /// Comprobantes ya subidos (del más nuevo al más viejo).
  List<TransferReceipt> receipts = const [];
  String? receiptsError;

  /// Hay datos con que transferir.
  bool get hasBankData => bankDetails?.canTransfer ?? false;

  /// La distribuidora no cargó ni CBU ni alias.
  bool get bankMissing => bankDetails != null && !bankDetails!.canTransfer;

  bool get showTransferCard =>
      canPayByTransfer ||
      (isTransfer && receipts.isNotEmpty) ||
      paymentStateLabel == 'Pagado';
  bool get isTransfer => transferIsOnline;

  bool get canUploadReceipt =>
      canPayByTransfer &&
      !uploading &&
      receipts.length < TransferReceipt.maxPerOrder;

  /// Subiendo un comprobante: no se lanza otro encima.
  bool uploading = false;

  /// Qué dato se copió (`cbu` o `alias`), para confirmarlo en pantalla.
  String? copied;

  /// Lee datos bancarios y comprobantes. Una falla no tira el detalle: se
  /// muestra el error en la tarjeta y se conserva lo que ya había.
  Future<void> loadTransfer() async {
    if (!isTransfer) {
      bankDetails = null;
      bankError = null;
      receipts = const [];
      receiptsError = null;
      return;
    }
    if (canPayByTransfer) {
      final bank = await _transfer.bankDetails(transferOrderId);
      if (bank.ok) {
        bankDetails = bank.data;
        bankError = null;
      } else {
        bankError = bank.message;
      }
    }
    await loadReceipts();
  }

  Future<void> loadReceipts() async {
    final r = await _transfer.receipts(transferOrderId);
    if (r.ok) {
      receipts = r.data ?? const [];
      receiptsError = null;
    } else {
      receiptsError = r.message;
    }
  }

  /// Copia el CBU o el alias al portapapeles.
  Future<void> copy(String which, String value) async {
    await copyToClipboard(value);
    copied = which;
    notifyListeners();
  }

  /// Elige el comprobante (foto o PDF), lo sube y relee la lista. Un rechazo
  /// del back (pedido cancelado, pago ya resuelto, tope de 5) se muestra tal
  /// cual.
  Future<void> uploadReceipt(ReceiptSource source) async {
    if (!canUploadReceipt) return;
    uploading = true;
    notifyListeners();
    try {
      final PickedReceipt? file;
      try {
        file = await picker.pick(source);
      } on PhotoTooLarge {
        return _uploadFailed(PhotoTooLarge.message);
      } on ReceiptTooLarge {
        return _uploadFailed(ReceiptTooLarge.message);
      } on ReceiptUnreadable {
        return _uploadFailed(ReceiptUnreadable.message);
      } catch (_) {
        return _uploadFailed(PhotoUnreadable.message);
      }
      if (file == null) return;
      final result = await _transfer.upload(transferOrderId, file);
      if (!result.ok) {
        // Puede que el back ya lo tenga (reintento tras un corte): la lista dice la verdad.
        await loadReceipts();
        return _uploadFailed(result.message!);
      }
      await loadReceipts();
      await _dialogs.showDialog(
        title: 'Comprobante enviado',
        description: 'Lo recibimos. La distribuidora lo revisa y confirma tu '
            'pago.',
        buttonTitle: 'Aceptar',
      );
    } finally {
      uploading = false;
      notifyListeners();
    }
  }

  Future<void> _uploadFailed(String message) => _dialogs.showDialog(
        title: 'No pudimos subir el comprobante',
        description: message,
        buttonTitle: 'Aceptar',
      );

  /// Abre el comprobante en el visor del sistema. La URL firmada vence: si ya
  /// no vale se vuelve a pedir la lista.
  Future<void> openReceipt(TransferReceipt receipt) async {
    var current = receipt;
    if (!current.link.isValid) {
      await loadReceipts();
      notifyListeners();
      final fresh = receipts.where((r) => r.id == receipt.id);
      if (fresh.isEmpty) {
        await _dialogs.showDialog(
          title: 'No pudimos abrir el comprobante',
          description: receiptsError ?? 'El comprobante ya no está disponible.',
          buttonTitle: 'Aceptar',
        );
        return;
      }
      current = fresh.first;
    }
    var opened = false;
    try {
      opened = await openUrl(Uri.parse(current.link.url));
    } catch (_) {}
    if (!opened) {
      await _dialogs.showDialog(
        title: 'No pudimos abrir el comprobante',
        description: 'Probá de nuevo en unos minutos.',
        buttonTitle: 'Aceptar',
      );
    }
  }
}
