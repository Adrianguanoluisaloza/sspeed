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
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ProductoDetalle(
      idDetalle: (map['id_detalle'] as num?)?.toInt() ?? 0,
      idProducto: (map['id_producto'] as num?)?.toInt() ?? 0,
      nombreProducto: map['nombre_producto']?.toString() ?? 'Sin nombre',
      imagenUrl: map['imagen_url']?.toString(),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      precioUnitario: parseDouble(map['precio_unitario']),
      subtotal: parseDouble(map['subtotal']),
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
