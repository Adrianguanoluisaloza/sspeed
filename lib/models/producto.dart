/// Modelo de datos para la tabla `productos` conforme al esquema SQL.
class Producto {
  final int idProducto;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;
  final String? categoria;
  final int? idCategoria;
  final bool disponible;
  final DateTime? fechaCreacion;

  const Producto({
    required this.idProducto,
    required this.nombre,
    required this.precio,
    this.descripcion,
    this.imagenUrl,
    this.categoria,
    this.idCategoria,
    this.disponible = true,
    this.fechaCreacion,
  });

  factory Producto.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Producto(
      idProducto: (map['id_producto'] as num?)?.toInt() ?? 0,
      nombre: map['nombre']?.toString() ?? 'Sin nombre',
      descripcion: map['descripcion']?.toString(),
      precio: parseDouble(map['precio']),
      imagenUrl: map['imagen_url']?.toString(),
      categoria: map['categoria']?.toString(),
      idCategoria: (map['id_categoria'] as num?)?.toInt(),
      disponible: map['disponible'] is bool
          ? map['disponible'] as bool
          : (map['disponible'] is num
              ? (map['disponible'] as num) != 0
              : true),
      fechaCreacion: parseDate(map['fecha_creacion']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'id_categoria': idCategoria,
      'disponible': disponible,
    }..removeWhere((key, value) => value == null);
  }

  bool get estaDisponible => disponible;
  String get categoriaVisible => categoria ?? 'Sin categoría';
}

class ProductoRankeado {
  final int idProducto;
  final String nombre;
  final double ratingPromedio;
  final int totalReviews;

  const ProductoRankeado({
    required this.idProducto,
    required this.nombre,
    required this.ratingPromedio,
    required this.totalReviews,
  });

  factory ProductoRankeado.fromMap(Map<String, dynamic> map) {
    final rating = map['rating_promedio'] as num? ?? 0.0;
    final reviews = map['total_reviews'] as num? ?? 0;

    return ProductoRankeado(
      idProducto: (map['id_producto'] as num?)?.toInt() ?? 0,
      nombre: map['nombre']?.toString() ?? 'Producto Desconocido',
      ratingPromedio: rating.toDouble(),
      totalReviews: reviews.toInt(),
    );
  }
}
