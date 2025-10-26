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
    // Normalizamos claves heterogéneas para que coincidan con el esquema de Postgres.
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
      readValue(['coordenadas_entrega', 'coordenadasEntrega', 'coordenadas']),
    );
    final rawLocation = readValue(['ubicacion', 'location']);
    final ubicacion = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : null;

    final double? latitud = parseDouble(
      readValue(['latitud', 'lat']) ??
          coordenadas?['latitud'] ??
          coordenadas?['lat'] ??
          ubicacion?['latitud'] ??
          ubicacion?['lat'],
    );
    final double? longitud = parseDouble(
      readValue(['longitud', 'lng', 'long']) ??
          coordenadas?['longitud'] ??
          coordenadas?['lng'] ??
          ubicacion?['longitud'] ??
          ubicacion?['lng'],
    );

    return Pedido(
      idPedido: parseInt(readValue(['id_pedido', 'idPedido'])) ?? 0,
      idCliente: parseInt(readValue(['id_cliente', 'idCliente'])) ?? 0,
      idDelivery: parseInt(readValue(['id_delivery', 'idDelivery'])),
      idUbicacion: parseInt(readValue(['id_ubicacion', 'idUbicacion'])),
      fechaPedido:
          parseDate(readValue(['fecha_pedido', 'fechaPedido'])) ?? DateTime.now(),
      fechaEntrega: parseDate(readValue(['fecha_entrega', 'fechaEntrega'])),
      estado: readValue(['estado', 'status'])?.toString() ?? 'pendiente',
      total: parseDouble(readValue(['total', 'montoTotal'])) ?? 0.0,
      direccionEntrega: readValue(
            ['direccion_entrega', 'direccionEntrega', 'address'],
          )?.toString() ??
          'No especificada',
      metodoPago: readValue(['metodo_pago', 'metodoPago', 'paymentMethod'])
              ?.toString() ??
          'efectivo',
      notas: readValue(['notas', 'comentarios', 'notes'])?.toString(),
      latitudDestino: latitud,
      longitudDestino: longitud,
      coordenadasEntrega: coordenadas,
    );
  }
}
