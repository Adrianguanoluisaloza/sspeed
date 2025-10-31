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
  final bool disponible; // CORRECCIÓN: Se añade el campo stock
  final int? stock;
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
    this.stock,
    this.fechaCreacion,
  });

  // CORRECCIÓN: Se refactoriza fromMap para ser más robusto y flexible.
  factory Producto.fromMap(Map<String, dynamic> map) {
    // Función auxiliar para leer un valor de múltiples claves posibles (snake_case, camelCase, etc.)
    dynamic readValue(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) return map[key];
      }
      return null;
    }

    // Funciones de parseo seguras
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    double parseDouble(dynamic value, {double fallback = 0.0}) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return Producto(
      idProducto: parseInt(readValue(['id_producto', 'idProducto', 'id'])),
      idNegocio: parseInt(readValue(['id_negocio', 'idNegocio'])),
      nombre:
          readValue(['nombre', 'name', 'producto'])?.toString() ?? 'Sin nombre',
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
      stock: parseInt(
          readValue(['stock'])), // CORRECCIÓN: Se lee el stock desde el mapa
      fechaCreacion: parseDate(
          readValue(['fecha_creacion', 'fechaCreacion', 'createdAt'])),
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
      'stock': stock,
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
  final double? precio;
  final String? descripcion;
  final String? imagenUrl;
  final String? negocio;
  final String? comentarioReciente;
  final DateTime? ultimaResena;

  const ProductoRankeado({
    required this.idProducto,
    required this.nombre,
    required this.ratingPromedio,
    required this.totalReviews,
    this.precio,
    this.descripcion,
    this.imagenUrl,
    this.negocio,
    this.comentarioReciente,
    this.ultimaResena,
  });

  /// Convierte este objeto a un [Producto] estándar para la pantalla de detalles.
  Producto toProducto() {
    return Producto(
      idProducto: idProducto,
      nombre: nombre,
      precio: precio ?? 0.0,
      descripcion: descripcion,
      imagenUrl: imagenUrl,
      // Los demás campos pueden ser nulos o tener valores por defecto
      // ya que la pantalla de detalles no los necesita de forma crítica.
    );
  }

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

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is DateTime) return value;
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value != null) {
          final text = value.toString();
          if (text.isNotEmpty) return text;
        }
      }
      return null;
    }

    double? parsePrecio() {
      final num? raw = readNumeric(['precio', 'price']);
      return raw?.toDouble();
    }

    return ProductoRankeado(
      idProducto: (readNumeric(['id_producto', 'idProducto']) ?? 0).toInt(),
      nombre: readString(['nombre', 'producto']) ?? 'Producto',
      ratingPromedio: (readNumeric([
                'rating_promedio',
                'ratingPromedio',
                'rating',
                'promedio',
                'average_rating'
              ]) ??
              0.0)
          .toDouble(),
      totalReviews: (readNumeric([
                'total_reviews',
                'totalReviews',
                'total',
                'cantidad',
                'reviews'
              ]) ??
              0)
          .toInt(),
      precio: parsePrecio(),
      descripcion: readString(['descripcion', 'description']),
      imagenUrl: readString(['imagen_url', 'imagenUrl', 'imageUrl']),
      negocio: readString(['negocio', 'business']),
      comentarioReciente: readString(
          ['comentario_reciente', 'comentarioReciente', 'latest_comment']),
      ultimaResena: readDate(['ultima_resena', 'ultimaResena', 'last_review']),
    );
  }

  bool get tieneComentario =>
      comentarioReciente != null && comentarioReciente!.trim().isNotEmpty;

  String get precioFormateado =>
      precio != null ? '\$${precio!.toStringAsFixed(2)}' : '';
}
