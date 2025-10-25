/// Modelo de datos para la tabla `usuarios`.
///
/// Se alinea estrictamente con el esquema definido en
/// `delivery_db_corrected.sql`, incorporando los campos agregados
/// posteriormente como `fecha_registro` y `activo`.
class Usuario {
  final int idUsuario;
  final String nombre;
  final String correo;
  final String rol;
  final String? telefono;
  final DateTime? fechaRegistro;
  final bool activo;
  final String? contrasena;
  final bool esInvitado;
  final String? token;

  const Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.telefono,
    this.fechaRegistro,
    this.contrasena,
    this.activo = true,
    this.esInvitado = false,
    this.token,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory Usuario.fromMap(Map<String, dynamic> map) {
    // Compatibilidad dual: aceptamos claves en snake_case o camelCase según la API.
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

    return Usuario(
      idUsuario: parseInt(readValue(['id_usuario', 'idUsuario'])),
      nombre: readValue(['nombre', 'name'])?.toString() ?? '',
      correo: readValue(['correo', 'email'])?.toString() ?? '',
      rol: readValue(['rol', 'role'])?.toString() ?? 'cliente',
      telefono: readValue(['telefono', 'phone'])?.toString(),
      fechaRegistro: parseDate(readValue(['fecha_registro', 'fechaRegistro'])),
      contrasena: readValue(['contrasena', 'password'])?.toString(),
      activo: (() {
        final raw = readValue(['activo', 'isActive']);
        if (raw is bool) return raw;
        if (raw is num) return raw != 0;
        if (raw is String) {
          return raw.toLowerCase() == 'true' || raw == '1';
        }
        return true;
      })(),
      token: readValue(['token', 'access_token', 'jwt'])?.toString(),
    );
  }

  /// Instancia utilizada para el modo invitado (sin autenticación).
  factory Usuario.guest() {
    return Usuario(
      idUsuario: 0,
      nombre: 'Invitado',
      correo: 'invitado@local',
      rol: 'invitado',
      activo: true,
      esInvitado: true,
      token: null,
    );
  }

  /// Conversión a mapa para peticiones POST/PUT cuando sea necesario.
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'telefono': telefono,
      'fecha_registro': fechaRegistro?.toIso8601String(),
      'activo': activo,
      'contrasena': contrasena,
      'token': token,
    }..removeWhere((key, value) => value == null);
  }

  bool get estaActivo => activo;
  bool get isGuest => esInvitado;

  /// Método auxiliar para actualizar propiedades opcionales sin perder la
  /// información original del usuario autenticado (por ejemplo, al adjuntar
  /// el token JWT proveniente de la API unificada).
  Usuario copyWith({
    int? idUsuario,
    String? nombre,
    String? correo,
    String? rol,
    String? telefono,
    DateTime? fechaRegistro,
    bool? activo,
    String? contrasena,
    bool? esInvitado,
    String? token,
  }) {
    return Usuario(
      idUsuario: idUsuario ?? this.idUsuario,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      telefono: telefono ?? this.telefono,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      contrasena: contrasena ?? this.contrasena,
      activo: activo ?? this.activo,
      esInvitado: esInvitado ?? this.esInvitado,
      token: token ?? this.token,
    );
  }
}
