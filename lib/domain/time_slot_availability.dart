/// Disponibilidad de una franja horaria para una fecha, tal como la devuelve
/// `GET /api/time-slot/availability`. `remaining` son los cupos libres ese día.
class TimeSlotAvailability {
  const TimeSlotAvailability({
    required this.timeSlotId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.remaining,
  });

  final String timeSlotId;
  final String name; // "Mañana", "Tarde"
  final String startTime; // "09:00:00"
  final String endTime; // "13:00:00"
  final int remaining;

  /// Sin cupos libres para la fecha: la franja se muestra pero no seleccionable.
  bool get isFull => remaining <= 0;

  /// Etiqueta lista para mostrar: "Mañana (09:00 – 12:00)".
  String get label => '$name (${_hhmm(startTime)} – ${_hhmm(endTime)})';

  static String _hhmm(String time) {
    // "09:00:00" -> "09:00"; tolera formatos ya cortos.
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  factory TimeSlotAvailability.fromJson(Map<String, dynamic> json) {
    final remainingRaw = json['remaining'] ?? json['capacity'];
    return TimeSlotAvailability(
      timeSlotId: json['timeSlotId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Franja',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      remaining: (remainingRaw is num) ? remainingRaw.toInt() : 0,
    );
  }
}
