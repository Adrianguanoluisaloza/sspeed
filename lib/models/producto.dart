/// Modelo de datos para la tabla `productos` conforme al esquema SQL.
class Producto {
  final int idProducto;
  final int? idNegocio;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;
  final String? categoria;
  final int? idCategoria;
  final bool disponible;
  final int? stock; // CAMPO AÃ‘ADIDO
  final DateTime? fechaCreacion;

  const Producto({
    required this.idProducto,
    required this.nombre,
    required this.precio,
    this.idNegocio,
    this.descripcion,
    this.imagenUrl,
    this.categoria,
    this.idCategoria,
    this.disponible = true,
    this.stock, // CAMPO AÃ‘ADIDO
    this.fechaCreacion,
  });

  factory Producto.fromMap(Map<String, dynamic> map) {
    // Funciones de parseo robustas
    dynamic readValue(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) return map[key];
      }
      return null;
    }
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return Producto(
      idProducto: parseInt(readValue(['id_producto', 'idProducto'])) ?? 0,
      idNegocio: parseInt(readValue(['id_negocio', 'idNegocio'])),
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
        if (raw is String) return raw.toLowerCase() == 'true' || raw == '1';
        return true;
      })(),
      stock: parseInt(readValue(['stock'])), // CAMPO AÃ‘ADIDO
      fechaCreacion: parseDate(readValue(['fecha_creacion', 'fechaCreacion', 'createdAt'])),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_producto': idProducto,
      'id_negocio': idNegocio,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'id_categoria': idCategoria,
      'disponible': disponible,
      'stock': stock, // CAMPO AÃ‘ADIDO
    }..removeWhere((key, value) => value == null);
  }

  bool get estaDisponible => disponible;
  String get categoriaVisible => categoria ?? 'Sin categoria';
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

  // CORRECCIÃ“N: Se aÃ±ade el factory constructor que faltaba
  factory ProductoRankeado.fromMap(Map<String, dynamic> map) {
    num? readNumeric(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) return value;
        if (value is String) {
          final parsed = num.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return ProductoRankeado(
      idProducto: (readNumeric(['id_producto', 'idProducto']) ?? 0).toInt(),
      nombre: (map['nombre'] ?? map['producto'])?.toString() ?? 'Producto Desconocido',
      ratingPromedio: (readNumeric(['rating_promedio', 'ratingPromedio', 'rating', 'promedio', 'average_rating']) ?? 0.0).toDouble(),
      totalReviews: (readNumeric(['total_reviews', 'totalReviews', 'total', 'cantidad', 'reviews']) ?? 0).toInt(),
    );
  }
}

