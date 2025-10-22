import 'package:flutter_application_2/models/pedido.dart';

// Modelo para un producto dentro del detalle de un pedido
class ProductoDetalle {
  final String nombreProducto;
  final String imagenUrl;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  ProductoDetalle({
    required this.nombreProducto,
    required this.imagenUrl,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ProductoDetalle.fromMap(Map<String, dynamic> map) {
    return ProductoDetalle(
      nombreProducto: map['nombre_producto'] ?? 'N/A',
      imagenUrl: map['imagen_url'] ?? '',
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Modelo para el objeto completo que devuelve la API
class PedidoDetalle {
  final Pedido pedido;
  final List<ProductoDetalle> detalles;

  PedidoDetalle({
    required this.pedido,
    required this.detalles,
  });

  factory PedidoDetalle.fromMap(Map<String, dynamic> map) {
    var detallesList = map['detalles'] as List<dynamic>? ?? [];
    List<ProductoDetalle> detalles = detallesList.map((d) => ProductoDetalle.fromMap(d)).toList();

    return PedidoDetalle(
      pedido: Pedido.fromMap(map['pedido'] ?? {}),
      detalles: detalles,
    );
  }
}
