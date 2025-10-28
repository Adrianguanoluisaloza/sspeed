/// Modelo de datos para la tabla `ubicaciones`.
class Ubicacion {
  final int? id;
  final int idUsuario;
  final double? latitud;
  final double? longitud;
  final String? direccion;
  final String? descripcion;
  final DateTime? fechaRegistro;
  final bool activa;

  const Ubicacion({
    this.id,
    required this.idUsuario,
    this.latitud,
    this.longitud,
    this.direccion,
    this.descripcion,
    this.fechaRegistro,
    this.activa = true,
  });

  factory Ubicacion.fromMap(Map<String, dynamic> map) {
    // El backend alterna entre snake_case y camelCase, por eso iteramos múltiples claves.
    dynamic readValue(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) {
          return map[key];
        }
      }
      return null;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

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
      id: parseInt(readValue(['id_ubicacion', 'idUbicacion', 'id'])),
      idUsuario: parseInt(readValue(['id_usuario', 'idUsuario'])),
      latitud: parseDouble(
        readValue(['latitud', 'lat', 'latitude']) ?? 0,
      ),
      longitud: parseDouble(
        readValue(['longitud', 'lng', 'long', 'longitude']) ?? 0,
      ),
      direccion:
          readValue(['direccion', 'direccion_entrega', 'address'])?.toString(),
      descripcion: readValue(['descripcion', 'description'])?.toString(),
      fechaRegistro:
          parseDate(readValue(['fecha_registro', 'fechaRegistro', 'createdAt'])),
      activa: (() {
        final raw = readValue(['activa', 'activo', 'isActive']);
        if (raw is bool) return raw;
        if (raw is num) return raw != 0;
        if (raw is String) {
          return raw.toLowerCase() == 'true' || raw == '1';
        }
        return true;
      })(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idUsuario': idUsuario,
      'latitud': latitud,
      'longitud': longitud,
      'direccion': direccion,
      'descripcion': descripcion,
      'activa': activa,
    };
  }
}
