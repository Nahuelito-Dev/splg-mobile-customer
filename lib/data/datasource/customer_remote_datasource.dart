import 'dart:developer';

import 'package:dio/dio.dart';

import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/domain/consumption.dart';

/// El back responde 409 cuando el email o el teléfono ya tienen cuenta.
class RegistrationConflictException implements Exception {
  const RegistrationConflictException();
}

/// El back rechazó el consumo declarado en el alta por estar fuera del rango
/// razonable y pide confirmarlo (no se creó la cuenta).
class ConsumptionOutOfRangeException implements Exception {
  const ConsumptionOutOfRangeException();
}

class CustomerRemoteDatasource {
  final _apiClient = ApiClient();

  Future<(bool, dynamic)> createCustomer(
    Map<String, dynamic> customerData,
  ) async {
    try {
      // Alta pública de clientes. La ruta anterior
      // (users/customer-registration) sigue andando para las versiones ya
      // publicadas, pero se va a retirar.
      final response = await _apiClient.post('auth/registro', customerData);

      if (response.statusCode == 201) {
        return (true, response.data);
      }
    } on DioException catch (e) {
      log('e in createCustomer: ${e.toString()}');
      if (e.response?.statusCode == 409) {
        throw const RegistrationConflictException();
      }
      if (isConsumptionOutOfRange(e.response?.statusCode, e.response?.data)) {
        throw const ConsumptionOutOfRangeException();
      }
    } catch (e) {
      log('e in createCustomer: ${e.toString()}');
    }

    return (false, null);
  }

  Future<(bool, dynamic)> fetchCustomerByEmail(
    String email,
    String token,
  ) async {
    try {
      final response = await _apiClient.get('users/email/$email', token);

      if (response.statusCode == 200) {
        return (true, response.data);
      }
    } catch (e) {
      log('e in fetchCustomerByEmail: ${e.toString()}');
    }

    return (false, null);
  }

  /// Actualiza datos del propio usuario (`PATCH /users/:id`). Solo se mandan
  /// los campos a cambiar (p.ej. full_name, phone_number).
  Future<ApiResult<void>> updateUser(
    String userId,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await _apiClient.patch('users/$userId', data, token);
      return response.statusCode == 200 || response.statusCode == 204
          ? const ApiResult.ok()
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      log('e in updateUser: ${e.toString()}');
      return ApiResult.fromError(e);
    }
  }

  /// Baja lógica de la propia cuenta (`DELETE /users/me`). Con pedidos en
  /// curso el back responde 409 con el motivo.
  Future<ApiResult<void>> deleteMe(String token) async {
    try {
      final response = await _apiClient.delete('users/me', token);
      return response.statusCode == 200 || response.statusCode == 204
          ? const ApiResult.ok()
          : const ApiResult.fail(ApiErrorText.generic);
    } catch (e) {
      log('e in deleteMe: ${e.toString()}');
      return ApiResult.fromError(e);
    }
  }
}
