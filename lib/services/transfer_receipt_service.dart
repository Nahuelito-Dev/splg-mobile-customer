import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/bank_details.dart';
import 'package:splg_customer/domain/transfer_receipt.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Pago por transferencia contra el back (API v2): datos bancarios del pedido
/// y comprobantes (subir y listar con URL firmada).
class TransferReceiptService {
  /// [tokenReader] sólo se inyecta en los tests.
  TransferReceiptService({Future<String?> Function()? tokenReader})
      : _tokenReader = tokenReader;

  final Future<String?> Function()? _tokenReader;
  final _api = ApiClient();
  late final _customerService = locator<CustomerService>();

  /// Una clave por archivo y pedido: reintentar tras una falla de red, 5xx o
  /// 429 lleva la misma y el back no duplica el comprobante.
  final _keys = IdempotencyKeys();

  /// El texto genérico de la lib no explica estos dos rechazos de la subida.
  static const _rejectionText = {
    413: 'El archivo pesa más de 10 MB. Probá con uno más liviano.',
    415: 'Subí una foto (JPG, PNG o WEBP) o un PDF.',
  };

  Future<String?> get _token async {
    final reader = _tokenReader;
    return reader != null ? reader() : _customerService.token;
  }

  static String _url(String orderId, String tail) =>
      '${AppConfig.apiV2Url}orders/$orderId/$tail';

  /// `GET /api/v2/orders/:id/bank-details`.
  Future<ApiResult<BankDetails>> bankDetails(String orderId) async {
    final token = await _token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    try {
      final r = await _api.get(_url(orderId, 'bank-details'), token);
      return ApiResult.ok(BankDetails.fromJson(r.data));
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  /// `GET /api/v2/orders/:id/transfer-receipt`: del más nuevo al más viejo.
  Future<ApiResult<List<TransferReceipt>>> receipts(String orderId) async {
    final token = await _token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    try {
      final r = await _api.get(_url(orderId, 'transfer-receipt'), token);
      final raw = r.data;
      final list = raw is List
          ? raw.map(TransferReceipt.tryParse).whereType<TransferReceipt>()
          : const <TransferReceipt>[];
      return ApiResult.ok(list.toList());
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  /// `POST /api/v2/orders/:id/transfer-receipt` (multipart, campo `file`).
  Future<ApiResult<void>> upload(String orderId, PickedReceipt file) async {
    final token = await _token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final intention =
        'receipt:$orderId:${file.filename}:${file.bytes.length}:${Object.hashAll(file.bytes)}';
    try {
      await _api.upload(
        'POST',
        _url(orderId, 'transfer-receipt'),
        file.bytes,
        file.filename,
        file.contentType,
        token,
        extraHeaders: {'Idempotency-Key': _keys.keyFor(intention)},
      );
      _keys.settle(intention, keep: false);
      return const ApiResult.ok();
    } catch (e) {
      final r = ApiResult<void>.fromError(e);
      _keys.settle(intention, keep: r.keepKey);
      final own = _rejectionText[r.status];
      return own == null ? r : ApiResult.fail(own, status: r.status);
    }
  }
}
