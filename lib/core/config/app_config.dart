/// Configuración de entorno de la app cliente, centralizada y sobreescribible
/// por `--dart-define` para device físico / staging / producción.
///
/// Ejemplos:
///   flutter run --dart-define=API_BASE_URL=https://api.splg.app \
///               --dart-define=DISTRIBUTOR=demo
class AppConfig {
  AppConfig._();

  /// Base del backend SIN el sufijo `/api`. Default localhost para desarrollo.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// `--dart-define=PUSH_ENABLED=false` evita pedir permiso de notificaciones
  /// y registrar el token FCM (recorridos automáticos en simulador, donde el
  /// prompt del sistema tapa la pantalla).
  static const bool pushEnabled =
      bool.fromEnvironment('PUSH_ENABLED', defaultValue: true);

  /// URL completa de la API v1 (`/api/v1/`; ver «Versiones de la API» en el back).
  static String get apiUrl => '$apiBaseUrl/api/v1/';

  /// Namespace de Socket.IO del gateway de clientes (misma base que la API,
  /// sin `/api`).
  static String get customersNamespace => '$apiBaseUrl/customers';

  /// Distribuidora (tenant) contra la que opera esta instancia de la app.
  /// Se envía en el header `X-Distributor` (slug o uuid) para que el backend
  /// resuelva el tenant del cliente, y se usa como `?distributor=` en los
  /// endpoints públicos (p.ej. franjas horarias).
  static const String distributorSlug = String.fromEnvironment(
    'DISTRIBUTOR',
    defaultValue: 'demo',
  );

  /// Back URLs de Checkout Pro de MercadoPago (deben coincidir con
  /// `MP_SUCCESS_URL` / `MP_FAILURE_URL` / `MP_PENDING_URL` del backend). El
  /// WebView de pago las usa para detectar cuándo MP redirige de vuelta y
  /// cerrarse solo, sin salir de la app.
  static const String mpSuccessUrl = String.fromEnvironment(
    'MP_SUCCESS_URL',
    defaultValue: 'https://splg.app/pago/exito',
  );
  static const String mpFailureUrl = String.fromEnvironment(
    'MP_FAILURE_URL',
    defaultValue: 'https://splg.app/pago/error',
  );
  static const String mpPendingUrl = String.fromEnvironment(
    'MP_PENDING_URL',
    defaultValue: 'https://splg.app/pago/pendiente',
  );
}
