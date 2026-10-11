import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_lib/network/api_error_text.dart';

/// Fotos del cliente contra el back: sube por multipart con el token (el back
/// valida tipo, contenido y tamaño) y sólo muestra URLs firmadas que vencen.
class PhotoService {
  final _api = ApiClient();
  final _customerService = locator<CustomerService>();

  /// Sube o reemplaza la foto propia (`PUT /users/me/photo`).
  Future<ApiResult<void>> uploadMyPhoto(PickedPhoto photo) =>
      _upload('PUT', 'users/me/photo', photo);

  /// Quita la foto propia (`DELETE /users/me/photo`).
  Future<ApiResult<void>> removeMyPhoto() async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    try {
      await _api.delete('users/me/photo', token);
      return const ApiResult.ok();
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  /// Sube la foto de un reclamo ya creado (`POST /claims/:id/photo`).
  Future<ApiResult<void>> uploadClaimPhoto(String claimId, PickedPhoto photo) =>
      _upload('POST', 'claims/$claimId/photo', photo);

  /// URL firmada de mi foto; `data` null si no tiene.
  Future<ApiResult<SignedUrl?>> myPhotoLink() => _link('users/me/photo');

  /// URL firmada de la foto de un reclamo; `data` null si no tiene.
  Future<ApiResult<SignedUrl?>> claimPhotoLink(String claimId) =>
      _link('claims/$claimId/photo');

  Future<ApiResult<void>> _upload(
      String method, String path, PickedPhoto photo) async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    try {
      await _api.upload(
          method, path, photo.bytes, photo.filename, photo.contentType, token);
      return const ApiResult.ok();
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }

  Future<ApiResult<SignedUrl?>> _link(String path) async {
    final token = await _customerService.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    try {
      final r = await _api.get('$path?modo=url', token);
      return ApiResult.ok(SignedUrl.fromLink(r.data));
    } catch (e) {
      return ApiResult.fromError(e);
    }
  }
}
