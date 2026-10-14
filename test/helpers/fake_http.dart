import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:splg_customer/core/network/api_client.dart';

/// Pedido que llegó al adaptador falso: sirve para comprobar método, ruta,
/// cabeceras y cuerpo que mandó la app.
class RecordedRequest {
  RecordedRequest(this.options);

  final RequestOptions options;

  String get method => options.method;
  String get path => options.path;
  Map<String, dynamic> get headers => options.headers;
  Map<String, dynamic> get query => options.queryParameters;
  Object? get body => options.data is String
      ? jsonDecode(options.data as String)
      : options.data;
}

/// Respuesta armada para un pedido; `error` simula que no hubo respuesta.
class FakeReply {
  const FakeReply(this.status, [this.body]) : error = null;
  const FakeReply.networkError()
      : status = null,
        body = null,
        error = DioExceptionType.connectionError;

  final int? status;
  final Object? body;
  final DioExceptionType? error;
}

/// Reemplaza el adaptador de red del [ApiClient] por uno que contesta con
/// [reply] y registra lo que se pidió. Devuelve el registro.
List<RecordedRequest> fakeHttp(
    FakeReply Function(RecordedRequest request) reply) {
  final log = <RecordedRequest>[];
  ApiClient().dio.httpClientAdapter = FakeAdapter((options) {
    final request = RecordedRequest(options);
    log.add(request);
    return reply(request);
  });
  return log;
}

/// Adaptador falso que se puede enchufar a cualquier `Dio`.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this._reply);

  final FakeReply Function(RequestOptions options) _reply;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = _reply(options);
    if (reply.error != null) {
      throw DioException(requestOptions: options, type: reply.error!);
    }
    return ResponseBody.fromString(
      jsonEncode(reply.body ?? {}),
      reply.status!,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
