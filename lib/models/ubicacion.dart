/// Modelo de datos para la tabla 'ubicaciones'
class Ubicacion {
  final int id;
  final int idUsuario;
  final double latitud;
  final double longitud;
  final String direccion;
  final DateTime fechaRegistro;

  Ubicacion({
    required this.id,
    required this.idUsuario,
    required this.latitud,
    required this.longitud,
    required this.direccion,
    required this.fechaRegistro,
  });

  factory Ubicacion.fromMap(Map<String, dynamic> map) {
    return Ubicacion(
      id: map['id_ubicacion'] ?? 0,
      idUsuario: map['id_usuario'] ?? 0,
      latitud: (map['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (map['longitud'] as num?)?.toDouble() ?? 0.0,
      direccion: map['direccion']?.toString() ?? 'Sin dirección',
      fechaRegistro: map['fecha_registro'] is DateTime
          ? map['fecha_registro']
          : DateTime.now(), // Fallback
    );
  }
}
