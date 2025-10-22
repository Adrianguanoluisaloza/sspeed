/// Modelo de datos para la tabla 'productos'.
class Producto {
  final int idProducto;
  final String nombre;
  final String descripcion;
  final double precio;
  final String imagenUrl;
  final String categoria;
  final bool disponible;
  // -----------------------------------------------------------

  Producto({
    required this.idProducto,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.imagenUrl,
    this.categoria = 'Varios',
    this.disponible = true,
  });

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      idProducto: map['id_producto'] ?? 0,
      nombre: map['nombre'] ?? 'Sin nombre',
      descripcion: map['descripcion'] ?? 'Sin descripción',
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      imagenUrl: map['imagen_url'] ?? '',
      categoria: map['categoria'] ?? 'Varios',
      disponible: map['disponible'] ?? false,
      // ----------------------------------------------------
    );
  }

  // Método para convertir el objeto a un Map (muy útil para enviar a la API)
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'disponible': disponible,
    };
  }
}
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
    final rating = map['rating_promedio'] as num? ?? 0.0;
    final reviews = map['total_reviews'] as num? ?? 0;

    return ProductoRankeado(
      idProducto: map['id_producto'] ?? 0,
      nombre: map['nombre']?.toString() ?? 'Producto Desconocido',
      ratingPromedio: rating.toDouble(),
      totalReviews: reviews.toInt(),
    );
  }
}
