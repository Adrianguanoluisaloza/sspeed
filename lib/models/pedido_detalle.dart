import 'pedido.dart';

/// Modelo para los ítems de la tabla `detalle_pedidos` con datos enriquecidos.
class ProductoDetalle {
  final int idDetalle;
  final int idProducto;
  final String nombreProducto;
  final String? imagenUrl;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  const ProductoDetalle({
    required this.idDetalle,
    required this.idProducto,
    required this.nombreProducto,
    required this.imagenUrl,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ProductoDetalle.fromMap(Map<String, dynamic> map) {
    // Adaptamos nombres de campos para consumir respuestas camelCase o snake_case.
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

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ProductoDetalle(
      idDetalle: parseInt(readValue(['id_detalle', 'idDetalle'])),
      idProducto: parseInt(readValue(['id_producto', 'idProducto'])),
      nombreProducto:
          readValue(['nombre_producto', 'nombreProducto', 'productName'])
                  ?.toString() ??
              'Sin nombre',
      imagenUrl: readValue(['imagen_url', 'imagenUrl', 'imageUrl'])?.toString(),
      cantidad: parseInt(readValue(['cantidad', 'quantity'])),
      precioUnitario:
          parseDouble(readValue(['precio_unitario', 'precioUnitario', 'price'])),
      subtotal: parseDouble(readValue(['subtotal', 'monto'])),
    );
  }
}

/// Modelo para la respuesta combinada de un pedido con sus detalles.
class PedidoDetalle {
  final Pedido pedido;
  final List<ProductoDetalle> detalles;

  const PedidoDetalle({
    required this.pedido,
    required this.detalles,
  });

  factory PedidoDetalle.fromMap(Map<String, dynamic> map) {
    final detallesList = map['detalles'] as List<dynamic>? ?? [];
    final detalles = detallesList
        .map((d) => ProductoDetalle.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

    return PedidoDetalle(
      pedido: Pedido.fromMap(Map<String, dynamic>.from(map['pedido'] as Map? ?? {})),
      detalles: detalles,
    );
  }
}
