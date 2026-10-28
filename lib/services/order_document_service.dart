import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_lib/network/api_error_text.dart';

enum OrderDocument {
  remito('remito', 'Remito'),
  recibo('recibo', 'Recibo');

  const OrderDocument(this.slug, this.label);

  final String slug;
  final String label;
}

/// Remito y recibo del pedido en PDF, generados por el back (API v2). Baja los
/// bytes con la sesión del cliente y los abre en la hoja nativa de ver,
/// guardar o compartir.
class OrderDocumentService {
  /// [share] y [tokenReader] sólo se inyectan en los tests.
  OrderDocumentService({
    Future<bool> Function(Uint8List bytes, String filename)? share,
    Future<String?> Function()? tokenReader,
  })  : _share = share ?? _sharePdf,
        _tokenReader = tokenReader;

  final Future<String?> Function()? _tokenReader;

  final Future<bool> Function(Uint8List bytes, String filename) _share;
  final _api = ApiClient();
  late final _customerService = locator<CustomerService>();

  /// Hoja nativa para ver, guardar o compartir el PDF (iOS y Android).
  static Future<bool> _sharePdf(Uint8List bytes, String filename) async {
    // Se escribe a un archivo con su nombre: con datos en memoria iOS muestra
    // la hoja sin nombre ni vista previa.
    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/$filename');
    await archivo.writeAsBytes(bytes, flush: true);
    final resultado = await SharePlus.instance.share(ShareParams(
      files: [XFile(archivo.path, mimeType: 'application/pdf')],
      // En iOS el encabezado de la hoja muestra el título, no el nombre del archivo.
      title: filename,
    ));
    return resultado.status != ShareResultStatus.unavailable;
  }

  /// Ruta del PDF (`GET /api/v2/orders/:id/{remito|recibo}.pdf`).
  static String url(String orderId, OrderDocument doc) =>
      '${AppConfig.apiV2Url}orders/$orderId/${doc.slug}.pdf';

  /// Nombre con el que se guarda el archivo: el mismo código corto que usan
  /// el back y el panel (`remito-0314ED62.pdf`).
  static String filename(String orderId, OrderDocument doc) {
    final codigo = orderId.replaceAll('-', '');
    final corto = codigo.length > 8 ? codigo.substring(0, 8) : codigo;
    return '${doc.slug}-${corto.toUpperCase()}.pdf';
  }

  /// Baja el PDF de [doc] del pedido [orderId].
  Future<ApiResult<Uint8List>> download(
      String orderId, OrderDocument doc) async {
    final token = await (_tokenReader?.call() ?? _customerService.token);
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    try {
      final r = await _api.getBytes(url(orderId, doc), token);
      final bytes = r.data;
      if (bytes == null || bytes.isEmpty) {
        return const ApiResult.fail(ApiErrorText.generic);
      }
      return ApiResult.ok(bytes);
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  /// Baja el PDF y abre la hoja nativa para verlo, guardarlo o compartirlo.
  Future<ApiResult<void>> open(String orderId, OrderDocument doc) async {
    final r = await download(orderId, doc);
    if (!r.ok) return ApiResult.fail(r.message!, status: r.status);
    try {
      await _share(r.data!, filename(orderId, doc));
      return const ApiResult.ok();
    } catch (_) {
      return const ApiResult.fail(ApiErrorText.generic);
    }
  }
}
