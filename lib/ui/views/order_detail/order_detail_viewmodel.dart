import 'package:flutter/services.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:splg_lib/domain/order.dart';

import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/bank_details.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/domain/order_refund.dart';
import 'package:splg_customer/domain/transfer_receipt.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/order_document_service.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_customer/services/transfer_receipt_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Detalle de un pedido con sus acciones según el estado: seguimiento,
/// calificar, reclamar, cancelar, modificar y repetir. Parte del pedido que
/// trae la lista y lo refresca con `GET /orders/:id`.
class OrderDetailViewModel extends LoadViewModel {
  OrderDetailViewModel({required this.orderId, Order? initial})
      : order = initial;

  final String orderId;

  final _history = locator<HistoryService>();
  final _nav = locator<NavigationService>();
  final _cart = locator<CartService>();
  final _sheets = locator<BottomSheetService>();
  final _dialogs = locator<DialogService>();
  final _documents = locator<OrderDocumentService>();
  final _transfer = locator<TransferReceiptService>();

  /// Se reemplazan en los tests.
  ReceiptPicker picker = ReceiptPicker();
  Future<void> Function(String text) copyToClipboard =
      (text) => Clipboard.setData(ClipboardData(text: text));
  Future<bool> Function(Uri url) openUrl =
      (url) => launchUrl(url, mode: LaunchMode.externalApplication);

  Order? order;

  /// Desglose del total y estado del cobro (`GET /orders/:id`); null hasta que
  /// se lee.
  OrderBreakdown? breakdown;

  /// Devoluciones del pago (`GET /orders/:id/refunds/mine`); vacía hasta que se
  /// leen o si no hubo ninguna.
  List<OrderRefund> refunds = const [];

  @override
  Future<void> fetch() async {
    try {
      _apply(await _history.fetchOrderDetail(orderId));
      await _loadRefunds();
      await _loadTransfer();
    } catch (e) {
      // Con el pedido de la lista a mano se muestra eso; sin él, el error. Un
      // pedido que ya no existe no se muestra con datos viejos.
      if (order == null || _isGone(e)) rethrow;
    }
  }

  void _apply(OrderDetail detail) {
    order = detail.order;
    breakdown = detail.breakdown;
  }

  /// Sólo un pedido cancelado, o uno express que pasó al reparto común, puede
  /// tener devolución. Si no se puede leer se queda con lo que ya mostraba.
  Future<void> _loadRefunds() async {
    final o = order;
    if (o == null) return;
    if (o.status != OrderStatus.cancelled && !expressDegraded) {
      refunds = const [];
      return;
    }
    final read = await _history.fetchOrderRefunds(orderId);
    if (read != null) refunds = read;
  }

  /// Pedido por transferencia: se pueden ver los datos bancarios y subir el
  /// comprobante mientras el pago esté pendiente (o marcado como no recibido,
  /// que el comprobante sirve para corregir) y el pedido no se haya cancelado.
  bool get canPayByTransfer =>
      order != null &&
      order!.paymentMethod == PaymentMethod.online &&
      order!.status != OrderStatus.cancelled &&
      const {'pending', 'failed'}
          .contains(breakdown?.paymentStatus ?? 'pending');

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
      canPayByTransfer || (isTransfer && receipts.isNotEmpty);
  bool get isTransfer => order?.paymentMethod == PaymentMethod.online;

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
  Future<void> _loadTransfer() async {
    if (!isTransfer) {
      bankDetails = null;
      bankError = null;
      receipts = const [];
      receiptsError = null;
      return;
    }
    if (canPayByTransfer) {
      final bank = await _transfer.bankDetails(orderId);
      if (bank.ok) {
        bankDetails = bank.data;
        bankError = null;
      } else {
        bankError = bank.message;
      }
    }
    await _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    final r = await _transfer.receipts(orderId);
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
      final result = await _transfer.upload(orderId, file);
      if (!result.ok) {
        // Puede que el back ya lo tenga (reintento tras un corte): la lista dice la verdad.
        await _loadReceipts();
        return _uploadFailed(result.message!);
      }
      await _loadReceipts();
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
      await _loadReceipts();
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

  static bool _isGone(Object e) => e is LoadFailure && !e.retryable;

  Future<void> _reload() async {
    try {
      _apply(await _history.fetchOrderDetail(orderId));
      await _loadRefunds();
      await _loadTransfer();
    } catch (e) {
      if (_isGone(e)) {
        order = null;
        loadError = LoadViewModel.errorText(e);
        canRetry = false;
      }
      // Cualquier otra falla: se queda con lo que ya tenía.
    }
    notifyListeners();
  }

  bool get _active => order != null && isActive(order!.status);

  bool get canTrack =>
      order?.status == OrderStatus.accepted ||
      order?.status == OrderStatus.outForDelivery;
  bool get canCancel => order?.status == OrderStatus.pending;
  bool get canModify => order != null && canEditOrder(order!, breakdown);
  bool get canRate => order?.status == OrderStatus.delivered;
  bool get canClaim => order?.status == OrderStatus.delivered;
  bool get canRepeat => order != null && !_active;
  bool get canChangeAddress =>
      order != null && !saving && canChangeOrderAddress(order!, breakdown);
  bool get canSetReceiver =>
      order != null && !saving && canSetOrderReceiver(order!);

  /// El remito sale siempre que el pedido exista.
  bool get canDownloadRemito => order != null;

  /// El recibo sólo con el pago acreditado y el pedido sin cancelar (si no, el
  /// back responde 409).
  bool get canDownloadRecibo =>
      order != null &&
      order!.status != OrderStatus.cancelled &&
      breakdown?.paymentStatus == 'paid';

  /// Documento que se está bajando; null si no hay descarga en curso.
  OrderDocument? downloading;

  /// El pedido es express, o lo fue y pasó al reparto común.
  bool get isExpress => breakdown?.isExpress ?? false;
  bool get expressDegraded => breakdown?.expressDegraded ?? false;

  /// El cobro ya se hizo por una pasarela o transferencia.
  bool get paidOnline =>
      breakdown?.paymentStatus == 'paid' &&
      order?.paymentMethod != PaymentMethod.cash;
  OrderReceiver? get receiver => breakdown?.receiver;

  /// Una fila por devolución: qué se devuelve y en qué estado está.
  List<({String title, String value})> get refundRows => [
        for (final r in refunds)
          (
            title: r.expressSurchargeOnly
                ? 'Reintegro del recargo express:'
                : 'Reintegro:',
            value: switch (r.status) {
              RefundStatus.pending => '${money.format(r.amount)} · en trámite',
              RefundStatus.succeeded => r.completedAt == null
                  ? '${money.format(r.amount)} · acreditado'
                  : '${money.format(r.amount)} · acreditado el ${dateLabel(r.completedAt!)}',
              RefundStatus.failed =>
                '${money.format(r.amount)} · no se pudo acreditar todavía; lo estamos revisando',
            },
          ),
      ];

  /// Hay un cambio (dirección) guardándose: no se lanza otro encima.
  bool saving = false;

  /// Elige otra de las direcciones del cliente para este pedido (CU-127). El
  /// back recalcula el total y rechaza lo que no corresponde (ya salió, pago en
  /// línea con otro recargo, fuera de cobertura): ese texto se muestra tal cual.
  Future<void> changeAddress() async {
    final o = order;
    if (o == null || saving) return;
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Elegí la dirección de entrega',
      data: {'selectedId': o.address?.addressId},
    );
    if (response?.confirmed != true || response?.data is! Address) return;
    final chosen = response!.data as Address;
    if (chosen.addressId == o.address?.addressId) return;

    saving = true;
    notifyListeners();
    final result = await _history.changeOrderAddress(orderId, chosen.addressId);
    saving = false;
    if (result.success) {
      // Lo que devolvió el back manda; la relectura sólo completa el desglose
      // y, si falla, no deshace el cambio.
      final updated = result.order;
      if (updated != null) order = updated;
      notifyListeners();
      await _reload();
      final now = order ?? updated ?? o;
      await _dialogs.showDialog(
        title: 'Dirección actualizada',
        description:
            'Tu pedido se entrega en ${now.address?.streetName ?? chosen.streetName}. '
            'El total ahora es ${money.format(now.total)}.',
        buttonTitle: 'Aceptar',
      );
      return;
    }
    notifyListeners();
    await _dialogs.showDialog(
      title: 'No pudimos cambiar la dirección',
      description: result.message,
      buttonTitle: 'Aceptar',
    );
    // El pedido pudo cambiar de estado (ya salió): se relee.
    if (result.rejected) await _reload();
  }

  /// Indica quién recibe el pedido (CU-128), desde la hoja del receptor.
  Future<void> editReceiver() async {
    if (order == null || saving) return;
    await _sheets.showCustomSheet(
      variant: BottomSheetType.receiver,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId, 'receiver': receiver},
    );
    // También tras un rechazo: el pedido pudo cambiar (ya se entregó).
    await _reload();
  }

  /// Baja el PDF y lo abre en la hoja nativa. Mientras baja no se lanza otra
  /// descarga; un error del back se muestra tal cual.
  Future<void> openDocument(OrderDocument doc) async {
    if (downloading != null) return;
    downloading = doc;
    notifyListeners();
    final result = await _documents.open(orderId, doc);
    downloading = null;
    notifyListeners();
    if (!result.ok) {
      await _dialogs.showDialog(
        title: 'No pudimos abrir el ${doc.label.toLowerCase()}',
        description: result.message,
        buttonTitle: 'Aceptar',
      );
    }
  }

  Future<void> track() async {
    await _nav.navigateToOrderTrackingView(orderId: orderId);
    await _reload();
  }

  Future<void> cancel() async {
    final cancelled = await _nav.navigateToCancelOrderView(orderId: orderId);
    if (cancelled == true) await _reload();
  }

  /// Abre la edición del pedido y, al volver, lo relee: haya guardado o no, el
  /// pedido pudo cambiar (o ya no ser editable porque lo tomó un repartidor).
  Future<void> modify() async {
    final o = order;
    if (o == null) return;
    await _nav.navigateToEditOrderView(order: o, breakdown: breakdown);
    await _reload();
  }

  /// Repetir: el carrito del back pasa a tener los ítems de este pedido y se
  /// sigue por el carrito, donde el cliente ve precios y disponibilidad de hoy.
  Future<void> repeat() async {
    final o = order;
    if (o == null) return;
    final r = await _cart.replaceWith(o.items);
    if (!r.ok) {
      await _dialogs.showDialog(
        title: 'No pudimos armar el carrito',
        description: r.message,
        buttonTitle: 'Aceptar',
      );
      return;
    }
    await _nav.navigateToCartView();
  }

  Future<void> rate() async {
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.rateDriver,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId, 'driverName': order?.deliveryName},
    );
    if (response?.confirmed == true) {
      await _dialogs.showDialog(
        title: '¡Gracias por calificar!',
        description: 'Tu opinión nos ayuda a mejorar el servicio.',
        buttonTitle: 'Aceptar',
      );
    }
  }

  Future<void> claim() async {
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.claim,
      isScrollControlled: true,
      enableDrag: false,
      data: {'orderId': orderId},
    );
    if (response?.confirmed == true) {
      await _dialogs.showDialog(
        title: 'Reclamo enviado',
        description:
            'Recibimos tu reclamo. Lo vamos a revisar y te contactamos.'
            '${response?.data is String ? '\n\n${response!.data}' : ''}',
        buttonTitle: 'Aceptar',
      );
    }
  }
}
