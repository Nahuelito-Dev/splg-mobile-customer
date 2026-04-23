class BusinessHours {
  BusinessHours({
    required int morningStart,
    required int morningEnd,
    required int afternoonStart,
    required int afternoonEnd,
  }) {
    _businessHours.add(_BusinessHours('Mañana', morningStart, morningEnd));
    _businessHours.add(_BusinessHours('Tarde', afternoonStart, afternoonEnd));
  }

  final List<_BusinessHours> _businessHours = [];

  int? _selectedStartHour;
  int? get selectedStartHour => _selectedStartHour;

  int? _selectedEndHour;
  int? get selectedEndHour => _selectedEndHour;

  List<int> get availableStartHours {
    List<int> hours = [];
    for (final range in _businessHours) {
      for (int i = range.startHour; i < range.endHour; i++) {
        hours.add(i);
      }
    }
    return hours;
  }

  List<int> get availableEndHours {
    if (_selectedStartHour == null) return [];

    final range = _businessHours.firstWhere(
      (r) =>
          _selectedStartHour! >= r.startHour && _selectedStartHour! < r.endHour,
      orElse: () => _businessHours.first,
    );

    List<int> hours = [];
    for (int i = _selectedStartHour! + 1; i <= range.endHour; i++) {
      hours.add(i);
    }
    return hours;
  }

  void setStartHour(int? hour) {
    if (_selectedStartHour == hour) return;
    _selectedStartHour = hour;
    _selectedEndHour = null;
  }

  void setEndHour(int? hour) {
    _selectedEndHour = hour;
  }
}

class _BusinessHours {
  final String label;
  final int startHour;
  final int endHour;

  const _BusinessHours(this.label, this.startHour, this.endHour);

  @override
  String toString() => '$startHour:00 - $endHour:00';
}
