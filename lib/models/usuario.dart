/// Modelo de datos para la tabla `usuarios`.
class Usuario {
  final int idUsuario;
  final String nombre;
  final String correo;
  final String rol;
  final String? telefono;
  final DateTime? fechaRegistro;
  final bool activo;

  const Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.telefono,
    this.fechaRegistro,
    this.activo = true,
  });

  /// Devuelve `true` si el usuario está autenticado (ID > 0).
  bool get isAuthenticated => idUsuario > 0;

  /// Devuelve `true` si la cuenta del usuario está activa.
  bool get estaActivo => activo;

  /// Constructor para un usuario no autenticado.
  factory Usuario.noAuth() {
    return const Usuario(
      idUsuario: 0, // Un ID de 0 representa a un usuario no autenticado
      nombre: 'Visitante',
      correo: '',
      rol: 'ninguno',
      activo: false,
    );
  }

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory Usuario.fromMap(Map<String, dynamic> map) {
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
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return Usuario(
      idUsuario: parseInt(readValue(['id_usuario', 'idUsuario'])),
      nombre: readValue(['nombre', 'name'])?.toString() ?? '',
      correo: readValue(['correo', 'email'])?.toString() ?? '',
      rol: readValue(['rol', 'role'])?.toString() ?? 'cliente',
      telefono: readValue(['telefono', 'phone'])?.toString(),
      fechaRegistro: parseDate(readValue(['fecha_registro', 'fechaRegistro'])),
      activo: (() {
        final raw = readValue(['activo', 'isActive']);
        if (raw is bool) return raw;
        if (raw is num) return raw != 0;
        if (raw is String) {
          return raw.toLowerCase() == 'true' || raw == '1';
        }
        return true;
      })(),
    );
  }

  /// Conversión a mapa para peticiones POST/PUT.
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'telefono': telefono,
      'fecha_registro': fechaRegistro?.toIso8601String(),
      'activo': activo,
    }..removeWhere((key, value) => value == null);
  }
}
