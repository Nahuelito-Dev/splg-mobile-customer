import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_client.dart';

import '../helpers/fake_http.dart';

void main() {
  Future<String> salida({required bool debug, int status = 200}) async {
    final lines = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/'))
      ..interceptors.add(logger(
        debug: debug,
        logPrint: (o) => lines.add(o.toString()),
      ))
      ..httpClientAdapter = FakeAdapter((_) => FakeReply(status, {'ok': true}));
    try {
      await dio.post(
        'orders',
        data: {'nota': 'hola'},
        options: Options(headers: {'Authorization': 'Bearer secreto-123'}),
      );
    } on DioException {
      // El 4xx también se loguea.
    }
    return lines.join('\n');
  }

  test('nunca loguea el Bearer, ni en debug', () async {
    final out = await salida(debug: true);
    expect(out, isNotEmpty);
    expect(out, isNot(contains('secreto-123')));
    expect(out, isNot(contains('Authorization')));
  });

  test('tampoco en un error', () async {
    final out = await salida(debug: true, status: 400);
    expect(out, isNot(contains('secreto-123')));
  });

  test('en release no sale nada: ni cuerpos ni errores', () async {
    expect(await salida(debug: false), isEmpty);
    expect(await salida(debug: false, status: 500), isEmpty);
  });
}
