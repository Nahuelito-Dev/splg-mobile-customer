import 'package:dio/dio.dart';

import 'package:splg_customer/core/network/api_result.dart';

/// Lo que ve el cliente cuando el pedido que pide ya no existe o no es suyo
/// (`GET /orders/:id` responde 404 o 410).
const String kOrderGoneText = 'Este pedido ya no está disponible.';

/// El back dice que el pedido no existe para este usuario (404) o que ya no
/// está (410): volver a pedirlo no cambia nada.
bool isOrderGone(Object e) =>
    e is DioException &&
    (e.response?.statusCode == 404 || e.response?.statusCode == 410);

/// Falla de lectura de un pedido que no se reintenta.
const LoadFailure orderGoneFailure =
    LoadFailure(kOrderGoneText, retryable: false);
