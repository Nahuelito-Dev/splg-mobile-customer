/// Respuesta de `GET /coverage-zones/check` (CU-058): si unas coordenadas caen
/// dentro de las zonas de cobertura de la distribuidora y con qué recargo.
class CoverageCheck {
  const CoverageCheck({required this.covered, this.zoneName});

  final bool covered;
  final String? zoneName;

  static CoverageCheck? fromJson(dynamic raw) {
    if (raw is! Map || raw['covered'] is! bool) return null;
    final zone = raw['zone'];
    return CoverageCheck(
      covered: raw['covered'] as bool,
      zoneName:
          zone is Map ? zone['name']?.toString() : raw['zoneName']?.toString(),
    );
  }
}
