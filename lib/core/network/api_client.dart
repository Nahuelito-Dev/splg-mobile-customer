import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:splg_customer/core/config/app_config.dart';

/// Ante un 401 en un pedido autenticado avisa que la sesión dejó de valer.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(this.onUnauthorized);

  final void Function() onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // La baja de cuenta maneja su propio 401 (mensaje específico).
    final isAccountDelete = err.requestOptions.method == 'DELETE' &&
        err.requestOptions.path.endsWith('users/me');
    if (err.response?.statusCode == 401 &&
        !isAccountDelete &&
        err.requestOptions.headers.containsKey('Authorization')) {
      onUnauthorized();
    }
    handler.next(err);
  }
}

/// Registro de pedidos para depurar. Sólo en debug (en release no sale nada) y
/// nunca con las cabeceras: llevan el `Authorization: Bearer ...` del usuario.
PrettyDioLogger logger({
  bool debug = kDebugMode,
  void Function(Object object)? logPrint,
}) =>
    PrettyDioLogger(
      enabled: debug,
      requestHeader: false,
      requestBody: debug,
      responseBody: false,
      responseHeader: false,
      error: true,
      compact: true,
      logPrint: logPrint ?? print,
    );

class ApiClient {
  static final instance = ApiClient._();

  factory ApiClient() {
    return instance;
  }

  ApiClient._();

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  )
    ..interceptors.add(logger())
    ..interceptors.add(UnauthorizedInterceptor(() => onUnauthorized?.call()));

  /// Qué hacer cuando el back responde 401 a un pedido con token (se asigna al
  /// arrancar: lleva al login).
  static void Function()? onUnauthorized;

  Future<Response> get(String path, [String? token]) async {
    try {
      final response = await dio.get(
        path,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Client-Source': 'customer-app',
            'X-Distributor': AppConfig.distributorSlug,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(
    String path,
    Map<String, dynamic> body, [
    String? token,
    Map<String, String>? extraHeaders,
  ]) async {
    try {
      final response = await dio.post(
        path,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Client-Source': 'customer-app',
            'X-Distributor': AppConfig.distributorSlug,
            if (token != null) 'Authorization': 'Bearer $token',
            if (extraHeaders != null) ...extraHeaders,
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> patch(
    String path,
    Map<String, dynamic> body,
    String token, [
    Map<String, String>? extraHeaders,
  ]) async {
    try {
      final response = await dio.patch(
        path,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Client-Source': 'customer-app',
            'X-Distributor': AppConfig.distributorSlug,
            'Authorization': 'Bearer $token',
            if (extraHeaders != null) ...extraHeaders,
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(String path, String token) async {
    try {
      final response = await dio.delete(
        path,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Client-Source': 'customer-app',
            'X-Distributor': AppConfig.distributorSlug,
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(
    String path,
    Map<String, dynamic> body,
    String token,
  ) async {
    try {
      final response = await dio.put(
        path,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Client-Source': 'customer-app',
            'X-Distributor': AppConfig.distributorSlug,
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sube un archivo como multipart (campo `file`) al endpoint del back, con el
  /// token. Nunca se sube directo al almacenamiento.
  Future<Response> upload(
    String method,
    String path,
    Uint8List bytes,
    String filename,
    String contentType,
    String token,
  ) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    return dio.request(
      path,
      data: form,
      options: Options(
        method: method,
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'X-Client-Source': 'customer-app',
          'X-Distributor': AppConfig.distributorSlug,
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}
