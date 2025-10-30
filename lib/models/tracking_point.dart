import 'package:latlong2/latlong.dart';

class TrackingPoint {
  final double latitud;
  final double longitud;
  final int? orden;
  final DateTime? fecha;
  final String? descripcion;

  const TrackingPoint({
    required this.latitud,
    required this.longitud,
    this.orden,
    this.fecha,
    this.descripcion,
  });

  factory TrackingPoint.fromMap(Map<String, dynamic> map) {
    double? parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final lat = parseDouble(map['latitud'] ?? map['lat'] ?? map['latitude']);
    final lon = parseDouble(map['longitud'] ?? map['lng'] ?? map['longitude']);

    if (lat == null || lon == null) {
      throw ArgumentError(
          'Los datos del punto de tracking no tienen coordenadas válidas.');
    }

    return TrackingPoint(
      latitud: lat,
      longitud: lon,
      orden: map['orden'] is num
          ? (map['orden'] as num).toInt()
          : int.tryParse('${map['orden'] ?? ''}'),
      fecha: parseDate(map['fecha_evento'] ?? map['fecha'] ?? map['timestamp']),
      descripcion: map['descripcion']?.toString(),
    );
  }

  LatLng toLatLng() => LatLng(latitud, longitud);
}
