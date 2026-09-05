import 'package:intl/intl.dart';

import 'package:splg_customer/data/datasource/time_slot_remote_datasource.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';

/// Franjas horarias de entrega (agendamiento). El backend agenda por franjas
/// fijas con cupo diario (las administra el panel), así que el cliente elige
/// una de estas en el checkout en vez de un rango de horas libre.
class TimeSlotService {
  final _datasource = TimeSlotRemoteDatasource();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Franjas disponibles para [date] con sus cupos libres, ordenadas por hora.
  Future<List<TimeSlotAvailability>> availabilityFor(DateTime date) async {
    final raw = await _datasource.fetchAvailability(_dateFormat.format(date));
    return raw.map(TimeSlotAvailability.fromJson).toList();
  }
}
