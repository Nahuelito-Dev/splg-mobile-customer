import 'package:splg_lib/permissions/app_permission.dart';
import 'package:splg_lib/permissions/permission_copy.dart';
import 'package:splg_lib/permissions/permission_gateway.dart';
import 'package:splg_lib/permissions/permission_prompter.dart';
import 'package:splg_lib/permissions/permissions_service.dart';
import 'package:stacked_services/stacked_services.dart';

/// Permisos de la app cliente: cada uno se pide en el momento en que hace falta (ver
/// los llamados), con una explicación previa y con camino a Ajustes si queda
/// denegado para siempre. Los textos específicos de la app están acá.
class AppPermissions extends PermissionsService {
  AppPermissions({PermissionGateway? gateway, PermissionPrompter? prompter})
      : this._(
          gateway ?? const PermissionHandlerGateway(),
          prompter ?? NavigatorPermissionPrompter(StackedService.navigatorKey),
        );

  AppPermissions._(PermissionGateway gateway, PermissionPrompter prompter)
      : _photoCamera = PermissionsService(
          gateway: gateway,
          prompter: prompter,
          copy: _photoCameraCopy,
        ),
        super(gateway: gateway, prompter: prompter, copy: _copy);

  /// Misma cámara, otro motivo: el texto cambia según para qué se pide.
  final PermissionsService _photoCamera;

  /// Cámara para sacar una foto (perfil o reclamo). `ensure(camera)` queda para
  /// el QR de la entrega.
  Future<PermissionOutcome> ensureCameraForPhoto() =>
      _photoCamera.ensure(AppPermission.camera);

  static const Map<AppPermission, PermissionCopy> _photoCameraCopy = {
    AppPermission.camera: PermissionCopy(
      title: 'Cámara',
      rationale:
          'SPLG usa la cámara para sacar la foto de tu perfil o la de un reclamo.',
      deniedMessage:
          'Sin la cámara no podemos sacar la foto. Podés elegir una de tu galería.',
      settingsMessage:
          'La cámara está desactivada para SPLG. Activala desde Ajustes para sacar fotos, o elegí una de tu galería.',
    ),
  };

  static const Map<AppPermission, PermissionCopy> _copy = {
    AppPermission.location: PermissionCopy(
      title: 'Ubicación',
      rationale:
          'SPLG usa tu ubicación, sólo mientras la app está abierta, para ubicar en el mapa la dirección de entrega.',
      deniedMessage:
          'Sin la ubicación no podemos centrar el mapa en donde estás. Igual podés buscar la dirección a mano.',
      settingsMessage:
          'La ubicación está desactivada para SPLG. Activala desde Ajustes si querés que el mapa te ubique.',
    ),
    AppPermission.camera: PermissionCopy(
      title: 'Cámara',
      rationale:
          'SPLG usa la cámara para escanear el código QR que te muestra el chofer al entregar el pedido.',
      deniedMessage:
          'Sin la cámara no podemos escanear el QR de la entrega. Podés volver a intentarlo.',
      settingsMessage:
          'La cámara está desactivada para SPLG. Activala desde Ajustes para escanear el QR de la entrega.',
    ),
    AppPermission.notifications: PermissionCopy(
      title: 'Notificaciones',
      rationale:
          'SPLG te avisa por notificación cuando tu pedido cambia de estado: asignado, en camino y entregado.',
      deniedMessage:
          'Sin notificaciones no te vamos a avisar los cambios de tu pedido. Igual podés verlos dentro de la app.',
      settingsMessage:
          'Las notificaciones están desactivadas para SPLG. Activalas desde Ajustes para recibir los avisos de tu pedido.',
    ),
  };
}
