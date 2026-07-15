import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/data/datasource/claim_remote_datasource.dart';
import 'package:jennigas_customer/services/customer_service.dart';

/// Reclamos del cliente sobre un pedido (`POST /claims`). El backend los deja
/// PENDING para que el panel los resuelva; no hay listado del lado del cliente.
class ClaimService {
  final _datasource = ClaimRemoteDatasource();
  final _customerService = locator<CustomerService>();

  /// Crea un reclamo para [orderId]. `reason` es el motivo (etiqueta corta) y
  /// `description` el detalle. Devuelve `true` si el backend lo registró.
  Future<bool> createClaim({
    required String orderId,
    required String reason,
    required String description,
  }) async {
    final token = await _customerService.token;
    if (token == null) return false;

    final body = <String, dynamic>{
      'orderId': orderId,
      'customerId': _customerService.customer.customerId,
      'reason': reason,
      'description': description,
    };

    return _datasource.createClaim(body, token);
  }
}
