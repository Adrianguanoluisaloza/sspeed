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
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory Usuario.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Usuario(
      idUsuario: (map['id_usuario'] as num?)?.toInt() ?? 0,
      nombre: map['nombre']?.toString() ?? '',
      correo: map['correo']?.toString() ?? '',
      rol: map['rol']?.toString() ?? 'cliente',
      telefono: map['telefono']?.toString(),
      fechaRegistro: parseDate(map['fecha_registro']),
      contrasena: map['contrasena']?.toString(),
      activo: map['activo'] is bool
          ? map['activo'] as bool
          : (map['activo'] is num ? (map['activo'] as num) != 0 : true),
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
    }..removeWhere((key, value) => value == null);
  }

  bool get estaActivo => activo;
  bool get isGuest => esInvitado;
}
