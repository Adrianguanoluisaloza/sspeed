/// Modelo de datos para la tabla 'recomendaciones' (resena individual).
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
      fechaRecomendacion: parseDate(
        readValue([
          'fecha_recomendacion',
          'fechaRecomendacion',
          'fecha_creacion',
          'fechaCreacion',
          'fecha',
        ]),
      ),
    );
  }
}

/// Resumen con promedio y total de reseñas de un producto.
class RecomendacionResumen {
  final double ratingPromedio;
  final int totalResenas;

  const RecomendacionResumen({
    required this.ratingPromedio,
    required this.totalResenas,
  });

  factory RecomendacionResumen.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const RecomendacionResumen(ratingPromedio: 0.0, totalResenas: 0);
    }
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return RecomendacionResumen(
      ratingPromedio: parseDouble(
        map['rating_promedio'] ??
            map['ratingPromedio'] ??
            map['rating'] ??
            map['promedio'],
      ),
      totalResenas: parseInt(
        map['total_reviews'] ??
            map['totalReviews'] ??
            map['total'] ??
            map['cantidad'] ??
            map['reviews'],
      ),
    );
  }
}

/// Estructura completa devuelta por la API para un producto.
class RecomendacionesProducto {
  final RecomendacionResumen resumen;
  final List<Recomendacion> recomendaciones;

  const RecomendacionesProducto({
    required this.resumen,
    required this.recomendaciones,
  });

  factory RecomendacionesProducto.fromMap(Map<String, dynamic> map) {
    final resumenMap = (map['resumen'] as Map?)?.cast<String, dynamic>();
    final lista = (map['recomendaciones'] as List?)
            ?.whereType<Map>()
            .map((item) => Recomendacion.fromMap(item.cast<String, dynamic>()))
            .toList() ??
        const <Recomendacion>[];

    return RecomendacionesProducto(
      resumen: RecomendacionResumen.fromMap(resumenMap),
      recomendaciones: lista,
    );
  }

  static const RecomendacionesProducto vacio = RecomendacionesProducto(
    resumen: RecomendacionResumen(ratingPromedio: 0.0, totalResenas: 0),
    recomendaciones: <Recomendacion>[],
  );
}
