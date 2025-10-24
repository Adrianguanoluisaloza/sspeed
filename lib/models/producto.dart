/// Modelo de datos para la tabla `productos` conforme al esquema SQL.
class Producto {
  final int idProducto;
  final int? idNegocio; // AÑADIDO
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
    // Compatibilidad con respuestas en distintos formatos provenientes de la API.
    dynamic readValue(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) {
          return map[key];
        }
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

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
      idProducto: parseInt(readValue(['id_producto', 'idProducto'])) ?? 0,
      nombre: readValue(['nombre', 'name'])?.toString() ?? 'Sin nombre',
      descripcion: readValue(['descripcion', 'description'])?.toString(),
      precio: parseDouble(readValue(['precio', 'price'])),
      imagenUrl: readValue(['imagen_url', 'imagenUrl', 'imageUrl'])?.toString(),
      categoria: readValue(['categoria', 'category'])?.toString(),
      idCategoria: parseInt(readValue(['id_categoria', 'idCategoria'])),
      disponible: (() {
        final raw = readValue(['disponible', 'isAvailable']);
        if (raw is bool) return raw;
        if (raw is num) return raw != 0;
        if (raw is String) {
          return raw.toLowerCase() == 'true' || raw == '1';
        }
        return true;
      })(),
      fechaCreacion:
          parseDate(readValue(['fecha_creacion', 'fechaCreacion', 'createdAt'])),
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
    num? readNumeric(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) return value;
        if (value is String) {
          final parsedDouble = double.tryParse(value);
          if (parsedDouble != null) return parsedDouble;
          final parsedInt = int.tryParse(value);
          if (parsedInt != null) return parsedInt;
        }
      }
      return null;
    }

    final rating = readNumeric(['rating_promedio', 'ratingPromedio']) ?? 0.0;
    final reviews = readNumeric(['total_reviews', 'totalReviews']) ?? 0;

    final rawId = map['id_producto'] ?? map['idProducto'];

    return ProductoRankeado(
      idProducto: rawId is num
          ? rawId.toInt()
          : (rawId is String ? int.tryParse(rawId) ?? 0 : 0),
      nombre: map['nombre']?.toString() ?? 'Producto Desconocido',
      ratingPromedio: rating.toDouble(),
      totalReviews: reviews.toInt(),
    );
  }
}
