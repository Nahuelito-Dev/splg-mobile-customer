import 'package:uuid/uuid.dart';

import 'package:splg_lib/network/api_error_text.dart';

/// Lo que ve el usuario cuando el back rechaza con 422 porque la misma
/// `Idempotency-Key` ya se usó con otro cuerpo: el primer envío llegó, no hay
/// que mandarlo de nuevo con otra clave.
const String kIdempotencyConflictText =
    'Ya recibimos esta solicitud. Revisá tu lista antes de volver a intentar.';

/// Alta de pedido con 422 de idempotencia: el primer envío llegó.
const String kOrderMaybeCreatedText =
    'Tu pedido anterior puede haberse registrado: revisá Mis pedidos antes de '
    'volver a pedir.';

/// 422 de idempotencia del back ("Esa clave de idempotencia ya se usó con
/// otros datos…"). Otros 422 no cuentan.
bool isIdempotencyConflict(int? status, dynamic data) {
  if (status != 422 || data is! Map) return false;
  final m = data['message'];
  final text = switch (m) {
    String s => s,
    List l => l.join(' '),
    _ => '',
  };
  return text.toLowerCase().contains('idempoten');
}

/// Si tras este fallo hay que conservar la `Idempotency-Key` para el próximo
/// intento: sin respuesta (red, timeout), 5xx, 429, el 409 "en curso" y el 422
/// de la clave ya usada. En todos esos casos la primera llamada pudo haber
/// llegado, y una clave nueva duplicaría la operación. Con éxito o con un
/// rechazo de negocio la clave se descarta.
bool keepIdempotencyKey(int? status, dynamic data) =>
    ApiErrorText.isRetryable(status) ||
    ApiErrorText.isInProgress(status, data) ||
    isIdempotencyConflict(status, data);

/// Claves de idempotencia por intención (la acción con sus datos): la misma
/// intención reusa la clave mientras no se resuelva y no pase [ttl]. El back
/// guarda la respuesta 24 h; una clave conservada más allá de unos minutos
/// podría devolver la respuesta guardada de algo que el usuario ya borró.
class IdempotencyKeys {
  IdempotencyKeys({
    String Function()? newKey,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 30),
  })  : _newKey = newKey ?? (() => const Uuid().v4()),
        _now = now ?? DateTime.now;

  final String Function() _newKey;
  final DateTime Function() _now;
  final Duration ttl;
  final Map<String, (String, DateTime)> _keys = {};

  /// La clave de [intention]; se crea la primera vez o si la anterior venció.
  String keyFor(String intention) {
    final now = _now();
    final known = _keys[intention];
    if (known != null && now.difference(known.$2) < ttl) return known.$1;
    final key = _newKey();
    _keys[intention] = (key, now);
    return key;
  }

  /// Cierra el intento: la clave se conserva si [keep], si no se descarta.
  void settle(String intention, {required bool keep}) {
    if (!keep) _keys.remove(intention);
  }

  void clear() => _keys.clear();
}
