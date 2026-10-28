/// Datos para pagar por transferencia (`GET /api/v2/orders/:id/bank-details`).
/// Cada dato es null si la distribuidora no lo cargó.
class BankDetails {
  const BankDetails({this.cbu, this.alias, this.holder});

  final String? cbu;
  final String? alias;
  final String? holder;

  /// Hay al menos un dato con que transferir (CBU o alias).
  bool get canTransfer => cbu != null || alias != null;

  factory BankDetails.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    String? text(String key) {
      final v = m[key]?.toString().trim();
      return v == null || v.isEmpty ? null : v;
    }

    return BankDetails(
        cbu: text('cbu'), alias: text('alias'), holder: text('holder'));
  }
}
