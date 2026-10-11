import 'package:stacked/stacked.dart';

import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_customer/core/network/api_result.dart';

export 'package:splg_customer/core/network/api_result.dart' show LoadFailure;
import 'package:dio/dio.dart';

/// Base de las pantallas que leen datos del back: carga, error con reintento.
abstract class LoadViewModel extends BaseViewModel {
  String? loadError;

  /// Trae los datos; si lanza, la pantalla muestra el error y "Reintentar".
  Future<void> fetch();

  Future<void> load() async {
    loadError = null;
    setBusy(true);
    try {
      await fetch();
    } catch (e) {
      loadError = errorText(e);
    }
    setBusy(false);
  }

  static String errorText(Object e) {
    if (e is DioException) {
      return ApiErrorText.of(e.response?.statusCode, e.response?.data);
    }
    if (e is LoadFailure) return e.message;
    return ApiErrorText.generic;
  }
}
