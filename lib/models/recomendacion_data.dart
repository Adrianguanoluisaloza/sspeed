
/// Modelo de datos para la tabla 'recomendaciones' (Reseña individual).
/// Mantengo la clase original por si la API la sigue usando para POSTs o detalles.
class Recomendacion {
  final int idRecomendacion;
  final int idUsuario;
  final int idProducto;
  final int puntuacion;
  final String? comentario;
  final DateTime? fechaRecomendacion;

  const Recomendacion({
    required this.idRecomendacion,
    required this.idUsuario,
    required this.idProducto,
    required this.puntuacion,
    this.comentario,
    this.fechaRecomendacion,
  });

  factory Recomendacion.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Recomendacion(
      idRecomendacion: (map['id_recomendacion'] as num?)?.toInt() ?? 0,
      idUsuario: (map['id_usuario'] as num?)?.toInt() ?? 0,
      idProducto: (map['id_producto'] as num?)?.toInt() ?? 0,
      puntuacion: (map['puntuacion'] as num?)?.toInt() ?? 0,
      comentario: map['comentario']?.toString(),
      fechaRecomendacion: parseDate(map['fecha_recomendacion']),
    );
  }
}
