/// URL firmada que da el back para ver un archivo, con su vencimiento. Vive
/// sólo en memoria: al vencer se vuelve a pedir.
class SignedUrl {
  const SignedUrl(this.url, this.expiresAt);

  final String url;
  final DateTime expiresAt;

  /// Margen para no mostrar una URL que vence mientras se descarga.
  static const margin = Duration(seconds: 20);

  bool get isValid => isValidAt(DateTime.now());

  bool isValidAt(DateTime now) => now.isBefore(expiresAt.subtract(margin));

  /// De `{ url, expiresAt }` (`?modo=url`); null si no hay foto.
  static SignedUrl? fromLink(Object? json) {
    if (json is! Map) return null;
    final url = json['url']?.toString();
    if (url == null || url.isEmpty) return null;
    final exp = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    return SignedUrl(url, exp ?? fromAwsQuery(url) ?? DateTime.now());
  }

  /// De una URL prefirmada de S3 sin `expiresAt` aparte (ej. el catálogo):
  /// `X-Amz-Date` + `X-Amz-Expires`.
  static SignedUrl? fromPresigned(Object? raw) {
    final url = raw?.toString();
    if (url == null || url.isEmpty) return null;
    return SignedUrl(url, fromAwsQuery(url) ?? DateTime.now());
  }

  static DateTime? fromAwsQuery(String url) {
    final q = Uri.tryParse(url)?.queryParameters;
    final date = q?['X-Amz-Date'];
    final secs = int.tryParse(q?['X-Amz-Expires'] ?? '');
    if (date == null || secs == null || date.length != 16) return null;
    final iso = '${date.substring(0, 4)}-${date.substring(4, 6)}-'
        '${date.substring(6, 8)}T${date.substring(9, 11)}:'
        '${date.substring(11, 13)}:${date.substring(13, 15)}Z';
    final start = DateTime.tryParse(iso);
    return start?.add(Duration(seconds: secs));
  }
}
