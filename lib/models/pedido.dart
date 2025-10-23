import 'dart:convert';

class Pedido {
  final int idPedido;
  final int idCliente;
  final int? idDelivery;
  final int? idUbicacion;
  final DateTime fechaPedido;
  final DateTime? fechaEntrega;
  final String estado;
  final double total;
  final String direccionEntrega;
  final String metodoPago;
  final String? notas;
  final double? latitudDestino;
  final double? longitudDestino;
  final Map<String, dynamic>? coordenadasEntrega;

  const Pedido({
    required this.idPedido,
    required this.idCliente,
    required this.fechaPedido,
    required this.estado,
    required this.total,
    required this.direccionEntrega,
    required this.metodoPago,
    this.idDelivery,
    this.idUbicacion,
    this.fechaEntrega,
    this.notas,
    this.latitudDestino,
    this.longitudDestino,
    this.coordenadasEntrega,
  });

  factory Pedido.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String && value.isNotEmpty) {
        return double.tryParse(value);
      }
      return null;
    }

    Map<String, dynamic>? parseCoordinates(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is String && value.isNotEmpty) {
        try {
          return Map<String, dynamic>.from(jsonDecode(value) as Map);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final coordenadas = parseCoordinates(
      map['coordenadas_entrega'] ?? map['coordenadas'],
    );
    final ubicacion = map['ubicacion'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(map['ubicacion'] as Map)
        : null;

    final double? latitud = parseDouble(
      map['latitud'] ?? coordenadas?['latitud'] ?? ubicacion?['latitud'],
    );
    final double? longitud = parseDouble(
      map['longitud'] ?? coordenadas?['longitud'] ?? ubicacion?['longitud'],
    );

    return Pedido(
      idPedido: (map['id_pedido'] as num?)?.toInt() ?? 0,
      idCliente: (map['id_cliente'] as num?)?.toInt() ?? 0,
      idDelivery: (map['id_delivery'] as num?)?.toInt(),
      idUbicacion: (map['id_ubicacion'] as num?)?.toInt(),
      fechaPedido: parseDate(map['fecha_pedido']) ?? DateTime.now(),
      fechaEntrega: parseDate(map['fecha_entrega']),
      estado: map['estado']?.toString() ?? 'pendiente',
      total: parseDouble(map['total']) ?? 0.0,
      direccionEntrega: map['direccion_entrega']?.toString() ?? 'No especificada',
      metodoPago: map['metodo_pago']?.toString() ?? 'efectivo',
      notas: map['notas']?.toString(),
      latitudDestino: latitud,
      longitudDestino: longitud,
      coordenadasEntrega: coordenadas,
    );
  }
}