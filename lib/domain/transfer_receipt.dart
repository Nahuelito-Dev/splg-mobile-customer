import 'package:splg_customer/domain/signed_url.dart';

/// Comprobante de transferencia de un pedido con su URL firmada
/// (`GET /api/v2/orders/:id/transfer-receipt`). La URL vence: se pide de nuevo
/// al abrirlo.
class TransferReceipt {
  const TransferReceipt({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.link,
  });

  /// Tope del back por pedido.
  static const maxPerOrder = 5;

  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final SignedUrl link;

  bool get isPdf => mimeType == 'application/pdf';

  static TransferReceipt? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['attachmentId']?.toString();
    final url = json['url']?.toString();
    if (id == null || id.isEmpty || url == null || url.isEmpty) return null;
    final expires = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    return TransferReceipt(
      id: id,
      name: json['originalName']?.toString() ?? 'Comprobante',
      mimeType: json['mimeType']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ??
          DateTime.now(),
      link: SignedUrl(
          url, expires ?? SignedUrl.fromAwsQuery(url) ?? DateTime.now()),
    );
  }
}
