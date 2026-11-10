/// Promedio de las calificaciones que recibió un usuario
/// (`GET /ratings/user/:userId/summary`, CU-065).
class RatingSummary {
  const RatingSummary({required this.average, required this.count});

  final double average;
  final int count;

  bool get hasRatings => count > 0;

  /// "4,8 · 12 calificaciones" o "Todavía sin calificaciones".
  String get label {
    if (!hasRatings) return 'Todavía sin calificaciones';
    final avg = average.toStringAsFixed(1).replaceAll('.', ',');
    return '$avg ★ · $count ${count == 1 ? 'calificación' : 'calificaciones'}';
  }

  static RatingSummary? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final average = raw['average'];
    final count = raw['count'];
    final avg =
        average is num ? average.toDouble() : double.tryParse('$average');
    final n = count is num ? count.toInt() : int.tryParse('$count');
    if (avg == null || n == null) return null;
    return RatingSummary(average: avg, count: n);
  }
}
