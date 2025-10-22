
/// Modelo de datos para la tabla 'recomendaciones' (Reseña individual).
/// Mantengo la clase original por si la API la sigue usando para POSTs o detalles.
class Recomendacion {
  final int idRecomendacion; // Mapea a 'id_recomendacion'
  final int idUsuario; // Mapea a 'id_usuario'
  final int idProducto; // Mapea a 'id_producto'
  final int puntuacion; // Mapea a 'puntuacion' (ej. 1 a 5)
  final String comentario; // Mapea a 'comentario'

  Recomendacion({
    required this.idRecomendacion,
    required this.idUsuario,
    required this.idProducto,
    required this.puntuacion,
    required this.comentario,
  });

  factory Recomendacion.fromMap(Map<String, dynamic> map) {
    return Recomendacion(
      idRecomendacion: map['id_recomendacion'] ?? 0,
      idUsuario: map['id_usuario'] ?? 0,
      idProducto: map['id_producto'] ?? 0,
      puntuacion: map['puntuacion'] ?? 0,
      comentario: map['comentario']?.toString() ?? 'Sin comentario',
    );
  }
}

/// Nuevo Modelo de Datos para la pantalla de RANKING DE PRODUCTOS.
/// Asume que la API devuelve esta estructura agregada para el endpoint /recomendaciones.
class ProductoRankeado {
  final int idProducto;
  final String nombre;
  final double ratingPromedio;
  final int totalReviews;

  ProductoRankeado({
    required this.idProducto,
    required this.nombre,
    required this.ratingPromedio,
    required this.totalReviews,
  });

  factory ProductoRankeado.fromMap(Map<String, dynamic> map) {
    // Aseguramos que ratingPromedio se convierta a double
    final rating = map['rating_promedio'] as num? ?? 0.0;

    // Aseguramos que totalReviews se convierta a int
    final reviews = map['total_reviews'] as num? ?? 0;

    return ProductoRankeado(
      idProducto: map['id_producto'] ?? 0,
      nombre: map['nombre']?.toString() ?? 'Producto Desconocido',
      ratingPromedio: rating.toDouble(),
      totalReviews: reviews.toInt(),
    );
  }
}
