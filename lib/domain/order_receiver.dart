/// Quién recibe el pedido cuando no es el cliente (CU-128): nombre, documento
/// y relación con el cliente.
class OrderReceiver {
  const OrderReceiver({
    required this.name,
    required this.document,
    required this.relationship,
  });

  final String name;
  final String document;
  final String relationship;

  /// Largos máximos y formato del documento, los del back
  /// (`SetOrderReceiverDto`).
  static const maxName = 120;
  static const maxRelationship = 40;
  static final _documentFormat = RegExp(r'^(?=.*\d)[A-Z0-9]{6,15}$');

  /// Documento como lo guarda el back: sin espacios, puntos ni guiones y en
  /// mayúsculas.
  static String normalizeDocument(String raw) =>
      raw.replaceAll(RegExp(r'[\s.\-]'), '').toUpperCase();

  /// Arma el receptor desde lo tipeado, o devuelve el texto del primer error.
  /// Los tres datos son obligatorios.
  static ({OrderReceiver? receiver, String? error}) parse({
    required String name,
    required String document,
    required String relationship,
  }) {
    final n = name.trim();
    final d = normalizeDocument(document);
    final r = relationship.trim();
    if (n.isEmpty) {
      return (receiver: null, error: 'Indicá el nombre de quien recibe.');
    }
    if (n.length > maxName) {
      return (
        receiver: null,
        error: 'El nombre puede tener hasta $maxName caracteres.'
      );
    }
    if (!_documentFormat.hasMatch(d)) {
      return (
        receiver: null,
        error: 'El documento no es válido: DNI, CUIT/CUIL o pasaporte, de 6 a '
            '15 letras o números.'
      );
    }
    if (r.isEmpty) {
      return (
        receiver: null,
        error: 'Indicá la relación con quien recibe (familiar, vecino...).'
      );
    }
    if (r.length > maxRelationship) {
      return (
        receiver: null,
        error: 'La relación puede tener hasta $maxRelationship caracteres.'
      );
    }
    return (
      receiver: OrderReceiver(name: n, document: d, relationship: r),
      error: null
    );
  }

  /// Cuerpo de `PATCH /orders/:id/receiver` y del campo `receiver` del alta.
  Map<String, dynamic> toJson() => {
        'receiverName': name,
        'receiverDocument': document,
        'receiverRelationship': relationship,
      };

  /// Lee el `receiver` de la respuesta del pedido; null si no se indicó.
  static OrderReceiver? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString() ?? '';
    final document = raw['document']?.toString() ?? '';
    final relationship = raw['relationship']?.toString() ?? '';
    if (name.isEmpty && document.isEmpty && relationship.isEmpty) return null;
    return OrderReceiver(
        name: name, document: document, relationship: relationship);
  }
}
