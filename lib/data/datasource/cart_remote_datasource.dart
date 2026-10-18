import 'dart:developer';

import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Carrito persistente del back (`/cart`). Cada llamada devuelve el carrito
/// completo (JSON) o el texto de error listo para mostrar.
class CartRemoteDatasource {
  final _apiClient = ApiClient();

  Future<ApiResult<dynamic>> fetch(String token) =>
      _run('fetch', () => _apiClient.get('cart', token));

  Future<ApiResult<dynamic>> add(
          String gasCylinderId, int quantity, String token) =>
      _run(
        'add',
        () => _apiClient.post(
          'cart/items',
          {'gasCylinderId': gasCylinderId, 'quantity': quantity},
          token,
        ),
      );

  Future<ApiResult<dynamic>> setQuantity(
          String cartItemId, int quantity, String token) =>
      _run(
        'setQuantity',
        () => _apiClient.patch(
            'cart/items/$cartItemId', {'quantity': quantity}, token),
      );

  Future<ApiResult<dynamic>> remove(String cartItemId, String token) =>
      _run('remove', () => _apiClient.delete('cart/items/$cartItemId', token));

  Future<ApiResult<dynamic>> clear(String token) =>
      _run('clear', () => _apiClient.delete('cart', token));

  Future<ApiResult<dynamic>> _run(
      String name, Future<dynamic> Function() call) async {
    try {
      final response = await call();
      final status = response.statusCode as int?;
      if (status != null && status >= 200 && status < 300) {
        return ApiResult.ok(response.data);
      }
      return const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      log('e in cart.$name: ${e.runtimeType}');
      return ApiResult.fromError(e);
    }
  }
}
