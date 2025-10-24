
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
    // Se aceptan claves alternativas para mantener compatibilidad con la API existente.
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

    return Recomendacion(
      idRecomendacion: parseInt(readValue(['id_recomendacion', 'idRecomendacion'])),
      idUsuario: parseInt(readValue(['id_usuario', 'idUsuario'])),
      idProducto: parseInt(readValue(['id_producto', 'idProducto'])),
      puntuacion: parseInt(readValue(['puntuacion', 'rating', 'score'])),
      comentario: readValue(['comentario', 'comment'])?.toString(),
      fechaRecomendacion:
          parseDate(readValue(['fecha_recomendacion', 'fechaRecomendacion'])),
    );
  }
}
