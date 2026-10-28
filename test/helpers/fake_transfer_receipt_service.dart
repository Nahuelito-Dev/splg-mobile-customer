import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/bank_details.dart';
import 'package:splg_customer/domain/transfer_receipt.dart';
import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_customer/services/transfer_receipt_service.dart';

/// Servicio de transferencia con respuestas armadas por el test; registra las
/// llamadas.
class FakeTransferReceiptService implements TransferReceiptService {
  ApiResult<BankDetails> bank =
      const ApiResult.ok(BankDetails(cbu: '0170099220000067797370'));
  ApiResult<List<TransferReceipt>> list = const ApiResult.ok([]);
  ApiResult<void> uploadResult = const ApiResult.ok();

  final calls = <String>[];
  final uploaded = <PickedReceipt>[];

  @override
  Future<ApiResult<BankDetails>> bankDetails(String orderId) async {
    calls.add('bank:$orderId');
    return bank;
  }

  @override
  Future<ApiResult<List<TransferReceipt>>> receipts(String orderId) async {
    calls.add('receipts:$orderId');
    return list;
  }

  @override
  Future<ApiResult<void>> upload(String orderId, PickedReceipt file) async {
    calls.add('upload:$orderId');
    uploaded.add(file);
    return uploadResult;
  }
}
