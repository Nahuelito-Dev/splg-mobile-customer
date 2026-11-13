/// Configuración de entorno de la app cliente, centralizada y sobreescribible
/// por `--dart-define` para device físico / staging / producción.
///
/// Ejemplos:
///   flutter run --dart-define=API_BASE_URL=https://api.splg.app \
///               --dart-define=DISTRIBUTOR=demo
class AppConfig {
  AppConfig._();

  /// Dónde arranca el mapa mientras no hay GPS ni una dirección elegida: la ciudad
  /// donde opera la distribuidora. Por omisión, Posadas (Misiones);
  /// `--dart-define=MAP_LAT=... --dart-define=MAP_LNG=...` la cambia.
  static double get mapFallbackLat =>
      _coordenada(const String.fromEnvironment('MAP_LAT'), 90) ?? -27.3671;
  static double get mapFallbackLng =>
      _coordenada(const String.fromEnvironment('MAP_LNG'), 180) ?? -55.8961;

  /// Un número finito dentro de ±[limite]; si no, null (se usa Posadas).
  static double? _coordenada(String texto, double limite) {
    final v = double.tryParse(texto);
    return v != null && v.isFinite && v.abs() <= limite ? v : null;
  }

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

  /// URL completa de la API v2 (`/api/v2/`): sólo lo nuevo (PDFs); el resto de
  /// la app sigue en la v1.
  static String get apiV2Url => '$apiBaseUrl/api/v2/';

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

  /// Deep link con el que Mercado Pago devuelve al cliente a la app al
  /// terminar el pago: `splg://pago/{exito|pendiente|error}` (más el query que
  /// agrega MP: `payment_id`, `status`, `external_reference`...). El back lo
  /// arma en las `back_urls` de la preferencia; acá sólo se reconoce.
  static const String paymentLinkScheme = 'splg';
  static const String paymentLinkHost = 'pago';
}
