/// Modelo de datos para la tabla 'usuarios'
class Usuario {
  final int idUsuario;
  final String nombre;
  final String correo;
  final String contrasena;
  final String rol;
  final String telefono;

  Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.contrasena,
    required this.rol,
    required this.telefono,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      idUsuario: map['id_usuario'] ?? 0,
      nombre: map['nombre'] ?? '',
      correo: map['correo'] ?? '',
      // CLAVE: contrasena debe coincidir con el JSON de tu API de Java
      contrasena: map['contrasena'] ?? '',
      rol: map['rol'] ?? '',
      telefono: map['telefono'] ?? '',
    );
  }
}