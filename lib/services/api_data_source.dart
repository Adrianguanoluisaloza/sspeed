import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart' show AppConfig;
import '../models/cart_model.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../models/producto.dart';
import '../models/ubicacion.dart';
import '../models/usuario.dart';
import 'api_exception.dart';
import 'data_source.dart';

class ApiDataSource implements DataSource {
  final String _baseUrl = AppConfig.baseUrl;
  final http.Client _httpClient;

  ApiDataSource({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> get _jsonHeaders =>
      const {'Content-Type': 'application/json; charset=UTF-8'};

  Map<String, dynamic> _parseMapResponse(http.Response response) {
    final raw = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    debugPrint('   <- Response [${response.statusCode}]: $raw');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (raw == null) return {'success': true};
      if (raw is Map<String, dynamic>) return raw;
      if (raw is List<dynamic>) {
        // Algunos endpoints regresan listas puras; las envolvemos para no romper llamados existentes.
        return {'success': true, 'data': raw};
      }
      throw const ApiException('Respuesta inesperada del servidor.');
    }

    final message = raw is Map<String, dynamic>
        ? raw['message']?.toString()
        : 'Error del servidor (${response.statusCode})';
    throw ApiException(message ?? 'Error del servidor',
        statusCode: response.statusCode);
  }

  List<dynamic> _parseListResponse(http.Response response) {
    final raw = response.bodyBytes.isEmpty
        ? []
        : jsonDecode(utf8.decode(response.bodyBytes));
    debugPrint('   <- Response [${response.statusCode}]: (list)');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (raw is List<dynamic>) return raw;
      if (raw is Map<String, dynamic>) {
        const candidateKeys = [
          'data',
          'productos',
          'items',
          'pedidos',
          'ubicaciones',
          'detalles',
          'results',
          'usuarios',
          'recomendaciones',
        ];
        for (final key in candidateKeys) {
          final value = raw[key];
          if (value is List<dynamic>) {
            return value;
          }
        }
        for (final value in raw.values) {
          if (value is List<dynamic>) {
            return value;
          }
        }
      }
      throw const ApiException('Formato de lista no válido.');
    }

    final message = raw is Map<String, dynamic>
        ? raw['message']?.toString()
        : 'Error del servidor (${response.statusCode})';
    throw ApiException(message ?? 'Error del servidor',
        statusCode: response.statusCode);
  }

  ApiException _mapToApiException(Object error) {
    if (error is ApiException) {
      return error;
    }
    if (error is SocketException) {
      return const ApiException('No se pudo conectar al servidor.');
    }
    if (error is TimeoutException) {
      return const ApiException('Tiempo de espera agotado, intenta nuevamente.');
    }
    if (error is FormatException) {
      return const ApiException('Respuesta inesperada del servidor.');
    }
    return ApiException(error.toString());
  }

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 POST: $url');
    debugPrint('   -> Body: ${jsonEncode(data)}');
    try {
      final response = await _httpClient
          .post(url, headers: _jsonHeaders, body: jsonEncode(data))
          .timeout(_timeout);
      return _parseMapResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  Future<Map<String, dynamic>> _put(
      String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 PUT: $url');
    debugPrint('   -> Body: ${jsonEncode(data)}');
    try {
      final response = await _httpClient
          .put(url, headers: _jsonHeaders, body: jsonEncode(data))
          .timeout(_timeout);
      return _parseMapResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🗑️ DELETE: $url');
    try {
      final response = await _httpClient
          .delete(url, headers: _jsonHeaders)
          .timeout(_timeout);
      return _parseMapResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  Future<List<dynamic>> _get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 GET List: $uri');
    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      return _parseListResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  Future<Map<String, dynamic>> _getMap(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 GET Map: $url');
    try {
      final response = await _httpClient.get(url).timeout(_timeout);
      return _parseMapResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  // --- Implementaciones ---
  @override
  Future<Usuario?> login(String email, String password) async {
    final response = await _post('/login', {'correo': email, 'contrasena': password});
    if (response['success'] == false) {
      return null;
    }

    final dynamic rawUser =
        response['usuario'] ?? response['user'] ?? response['data'];

    if (rawUser is Map) {
      return Usuario.fromMap(Map<String, dynamic>.from(rawUser as Map));
    }
    return null;
  }

  @override
  Future<bool> register(String name, String email, String password, String phone) async {
    final response = await _post('/registro', {
      'nombre': name,
      'correo': email,
      'contrasena': password,
      'telefono': phone,
    });
    final success = response['success'];
    if (success is bool) {
      return success;
    }
    final status = response['status']?.toString().toLowerCase();
    if (status != null) {
      return status == 'ok' || status == 'success';
    }
    return (response['usuario'] ?? response['user']) != null;
  }

  @override
  Future<List<Producto>> getProductos({String? query, String? categoria}) async {
    String endpoint = '/productos';
    Map<String, String> queryParams = {};
    if (query != null && query.isNotEmpty) queryParams['q'] = query;
    if (categoria != null && categoria.isNotEmpty) queryParams['categoria'] = categoria;

    if (queryParams.isNotEmpty) {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
      endpoint = uri.toString().replaceFirst(_baseUrl, '');
    }
    final data = await _get(endpoint);
    return data
        .map((item) => Producto.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<List<Producto>> getAllProductosAdmin() async {
    final data = await _get('/admin/productos');
    return data
        .map((item) => Producto.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<Producto?> createProducto(Producto producto) async {
    final response = await _post('/admin/productos', producto.toMap());
    if (response['success'] == true && response['producto'] != null) {
      return Producto.fromMap(
        Map<String, dynamic>.from(response['producto'] as Map),
      );
    }
    return null;
  }

  @override
  Future<bool> updateProducto(Producto producto) async {
    final response = await _put('/admin/productos/${producto.idProducto}', producto.toMap());
    return response['success'] ?? false;
  }

  @override
  Future<bool> deleteProducto(int idProducto) async {
    final response = await _delete('/admin/productos/$idProducto');
    return response['success'] ?? false;
  }
  @override
  Future<List<ProductoRankeado>> getRecomendaciones() async {
    final data = await _get('/recomendaciones');
    return data
        .map((item) =>
            ProductoRankeado.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
  // --- NUEVO MÉTODO PARA AÑADIR RECOMENDACIÓN ---
  @override
  Future<bool> addRecomendacion({
    required int idProducto,
    required int idUsuario,
    required int puntuacion,
    String? comentario,
  }) async {
    final response = await _post('/productos/$idProducto/recomendaciones', {
      'id_usuario': idUsuario,
      'puntuacion': puntuacion,
      'comentario': comentario ?? '',
    });
    return response['success'] ?? false;
  }

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) async {
    final data = await _get('/ubicaciones/usuario/$idUsuario');
    return data
        .map((item) => Ubicacion.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> placeOrder({required Usuario user, required CartModel cart, required Ubicacion location}) async {
    const double shippingCost = 2.00;
    final double total = cart.total + shippingCost;
    final productosJson = cart.items.map((item) => {
      'id_producto': item.producto.idProducto,
      'cantidad': item.quantity,
      'precio_unitario': item.producto.precio,
    }).toList();

    final payload = {
      'id_cliente': user.idUsuario,
      'id_ubicacion': location.id > 0 ? location.id : null,
      'direccion_entrega':
          location.direccion ?? 'Sin dirección registrada', // Evitamos violar el NOT NULL del esquema.
      'total': total,
      'metodo_pago': 'efectivo',
      'productos': productosJson,
    }..removeWhere((key, value) => value == null);

    final response = await _post('/pedidos', payload);
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidos(int idUsuario) async {
    final data = await _get('/pedidos/cliente/$idUsuario');
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) async {
    final data = await _getMap('/pedidos/$idPedido');
    final payload = data.containsKey('pedido') && data.containsKey('detalles')
        ? data
        : (data['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['data'] as Map)
            : data);
    if (payload.containsKey('pedido') && payload.containsKey('detalles')) {
      return PedidoDetalle.fromMap(payload);
    }
    throw const ApiException('Estructura de datos de pedido inválida.');
  }

  @override
  Future<List<Pedido>> getPedidosPorEstado(String estado) async {
    final data = await _get('/pedidos/estado/$estado');
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) async {
    final response = await _put('/pedidos/$idPedido/estado', {'estado': nuevoEstado});
    return response['success'] ?? false;
  }

  // --- NUEVO MÉTODO IMPLEMENTADO ---
  @override
  Future<Map<String, dynamic>> getAdminStats() async =>
      _getMap('/admin/stats');

  @override
  Future<List<Pedido>> getPedidosDisponibles() async {
    final data = await _get('/pedidos/disponibles');
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> asignarPedido(int idPedido, int idDelivery) async {
    final response = await _put('/pedidos/$idPedido/asignar', {'id_delivery': idDelivery});
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) async {
    final data = await _get('/pedidos/delivery/$idDelivery');
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon) async {
    try {
      final response = await _put('/repartidor/$idRepartidor/ubicacion', {
        'latitud': lat,
        'longitud': lon,
      });
      return response['success'] ?? true;
    } catch (e) {
      debugPrint('Error al actualizar ubicación: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) async {
    try {
      final data = await _getMap('/pedidos/$idPedido/tracking');
      if (data['success'] == true && data['ubicacion'] != null) {
        return Map<String, dynamic>.from(data['ubicacion'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching tracking data: $e");
      return null;
    }
  }
}

