import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lo que el pedido (`GET /orders/:id`) dice del repartidor.
class DriverSnapshot {
  const DriverSnapshot({
    this.hasBlock = false,
    this.id,
    this.name,
    this.phone,
    this.rating,
    this.vehicleName,
    this.vehiclePlate,
    this.lastLocation,
    this.lastLocationAt,
  });

  /// El pedido trae el bloque `driver`. Sin él (null) el back no expone al
  /// chofer: el pedido no tiene chofer, o no está aceptado ni en camino.
  final bool hasBlock;

  final String? id;
  final String? name;
  final String? phone;

  /// Promedio de calificaciones visibles; null si todavía no tiene ninguna.
  final double? rating;
  final String? vehicleName;
  final String? vehiclePlate;

  /// Última ubicación conocida del chofer: el back la manda sólo con el pedido
  /// en camino y reciente.
  final LatLng? lastLocation;
  final DateTime? lastLocationAt;
}

/// Único punto donde el seguimiento lee del pedido los datos del repartidor.
///
/// Contrato del back (`docs/PEDIDOS.md`): `driver` = `{ userId, fullName,
/// phoneNumber, ratingAverage, ratingCount, location: { lat, lng, at } | null }`
/// o `null`; el vehículo, en `vehicle: { patent, brand, model }`. `delivery_id`
/// y `delivery_name` siguen en el pedido y sirven cuando `driver` no viene.
class OrderDriverReader {
  OrderDriverReader._();

  static DriverSnapshot read(Map<String, dynamic> raw) {
    final block = _map(raw['driver']);
    final vehicle = _map(raw['vehicle']);
    final vehicleName = [
      _text(vehicle?['brand']),
      _text(vehicle?['model']),
    ].whereType<String>().join(' ');
    final location = _map(block?['location']);
    final lat = _number(location?['lat']);
    final lng = _number(location?['lng']);
    final count = _number(block?['ratingCount']) ?? 0;
    final average = _number(block?['ratingAverage']);
    return DriverSnapshot(
      hasBlock: block != null,
      id: _text(block?['userId']) ?? _text(raw['delivery_id']),
      name: _text(block?['fullName']) ?? _text(raw['delivery_name']),
      phone: _text(block?['phoneNumber']),
      rating: count > 0 && average != null && average > 0 ? average : null,
      vehicleName: vehicleName.isEmpty ? null : vehicleName,
      vehiclePlate: _text(vehicle?['patent']),
      lastLocation: lat == null || lng == null ? null : LatLng(lat, lng),
      lastLocationAt: DateTime.tryParse(_text(location?['at']) ?? ''),
    );
  }

  static Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? v.map((k, value) => MapEntry(k.toString(), value)) : null;

  static String? _text(dynamic v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static double? _number(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
}
