/// Modelo de datos para la tabla `ubicaciones`.
class Ubicacion {
  final int id;
  final int idUsuario;
  final double latitud;
  final double longitud;
  final String? direccion;
  final DateTime? fechaRegistro;
  final bool activa;

  const Ubicacion({
    required this.id,
    required this.idUsuario,
    required this.latitud,
    required this.longitud,
    this.direccion,
    this.fechaRegistro,
    this.activa = true,
  });

  factory Ubicacion.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Ubicacion(
      id: (map['id_ubicacion'] as num?)?.toInt() ?? 0,
      idUsuario: (map['id_usuario'] as num?)?.toInt() ?? 0,
      latitud: parseDouble(map['latitud']),
      longitud: parseDouble(map['longitud']),
      direccion: map['direccion']?.toString(),
      fechaRegistro: parseDate(map['fecha_registro']),
      activa: map['activa'] is bool
          ? map['activa'] as bool
          : (map['activa'] is num ? (map['activa'] as num) != 0 : true),
    );
  }
}
