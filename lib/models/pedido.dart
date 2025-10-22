class Pedido {
  final int idPedido;
  final DateTime fechaPedido;
  final String estado;
  final double total;
  final String direccionEntrega;

  // --- CAMPOS AÑADIDOS ---
  // (Ubicación del DESTINO/CLIENTE, no del repartidor)
  final double latitud;
  final double longitud;
  // -----------------------

  Pedido({
    required this.idPedido,
    required this.fechaPedido,
    required this.estado,
    required this.total,
    required this.direccionEntrega,
    // --- AÑADIDOS ---
    required this.latitud,
    required this.longitud,
  });

  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      idPedido: map['id_pedido'] ?? 0,
      fechaPedido: DateTime.tryParse(map['fecha_pedido'] ?? '') ?? DateTime.now(),
      estado: map['estado'] ?? 'desconocido',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      direccionEntrega: map['direccion_entrega'] ?? 'No especificada',

      // --- AÑADIDOS ---
      // Leemos la latitud y longitud del destino que vienen en el JSON 'pedido'
      latitud: (map['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (map['longitud'] as num?)?.toDouble() ?? 0.0,
    );
  }
}