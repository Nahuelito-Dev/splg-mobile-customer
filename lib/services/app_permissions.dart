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
  AppPermissions()
      : super(
          gateway: const PermissionHandlerGateway(),
          prompter: NavigatorPermissionPrompter(StackedService.navigatorKey),
          copy: _copy,
        );

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
          'SPLG usa la cámara para escanear el código QR que te muestra el chofer al entregar el pedido y para sacar fotos de un reclamo.',
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
