import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart' show AppConfig;
import '../models/cart_model.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
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
  String? _token;

  ApiDataSource({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  void setAuthToken(String? token) {
    _token = token;
  }

  Map<String, String> get _jsonHeaders {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _parseMapResponse(http.Response response) async {
    final raw = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    debugPrint('   <- Response [${response.statusCode}]: $raw');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (raw == null) return {'success': true};
      if (raw is Map<String, dynamic>) return raw;
      if (raw is List<dynamic>) return {'success': true, 'data': raw};
      throw const ApiException('Respuesta inesperada del servidor.');
    }

    final message = raw is Map<String, dynamic> ? raw['message']?.toString() : 'Error del servidor (${response.statusCode})';
    throw ApiException(message ?? 'Error del servidor', statusCode: response.statusCode);
  }

  Future<List<dynamic>> _parseListResponse(http.Response response) async {
    final raw = response.bodyBytes.isEmpty ? [] : jsonDecode(utf8.decode(response.bodyBytes));
    debugPrint('   <- Response [${response.statusCode}]: (list)');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (raw is List<dynamic>) return raw;
      if (raw is Map<String, dynamic>) {
        const keys = ['data', 'productos', 'items', 'pedidos', 'ubicaciones', 'detalles', 'results', 'usuarios', 'recomendaciones', 'conversaciones', 'mensajes'];
        for (final key in keys) {
          if (raw.containsKey(key) && raw[key] is List<dynamic>) return raw[key];
        }
      }
      throw const ApiException('Formato de lista no válido.');
    }

    final message = raw is Map<String, dynamic> ? raw['message']?.toString() : 'Error del servidor (${response.statusCode})';
    throw ApiException(message ?? 'Error del servidor', statusCode: response.statusCode);
  }

  ApiException _mapToApiException(Object error) {
    if (error is ApiException) return error;
    if (error is SocketException) return const ApiException('No se pudo conectar al servidor.');
    if (error is TimeoutException) return const ApiException('Tiempo de espera agotado, intenta nuevamente.');
    if (error is FormatException) return const ApiException('Respuesta inesperada del servidor.');
    return ApiException(error.toString());
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 POST: $url');
    try {
      final response = await _httpClient.post(url, headers: _jsonHeaders, body: jsonEncode(data)).timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 PUT: $url');
    try {
      final response = await _httpClient.put(url, headers: _jsonHeaders, body: jsonEncode(data)).timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  Future<List<dynamic>> _get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 GET List: $uri');
    try {
      final response = await _httpClient.get(uri, headers: _jsonHeaders).timeout(_timeout);
      return await _parseListResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  Future<Map<String, dynamic>> _getMap(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 GET Map: $url');
    try {
      final response = await _httpClient.get(url, headers: _jsonHeaders).timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  @override
  Future<Usuario?> login(String email, String password) async {
    final response = await _post('/login', {'correo': email, 'contrasena': password});
    final rawUser = response['usuario'] ?? response['user'] ?? response['data'];
    if (rawUser is Map<String, dynamic>) {
      return Usuario.fromMap(rawUser);
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
    return response['success'] ?? false;
  }
  
  @override
  Future<Usuario?> updateUsuario(Usuario usuario) async {
    final response = await _put('/usuarios/${usuario.idUsuario}', usuario.toMap());
    if (response['success'] == true && response['usuario'] != null) {
      return Usuario.fromMap(response['usuario'] as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<List<Producto>> getProductos({String? query, String? categoria}) async {
    final data = await _get('/productos');
    return data.map((item) => Producto.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) async {
    final data = await _get('/ubicaciones/usuario/$idUsuario');
    return data.map((item) => Ubicacion.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ProductoRankeado>> getRecomendaciones() async {
    final data = await _get('/recomendaciones');
    return data.map((item) => ProductoRankeado.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> addRecomendacion({required int idProducto, required int idUsuario, required int puntuacion, String? comentario}) async {
    final response = await _post('/productos/$idProducto/recomendaciones', {
      'id_usuario': idUsuario,
      'puntuacion': puntuacion,
      'comentario': comentario,
    });
    return response['success'] ?? false;
  }

  @override
  Future<bool> placeOrder({required Usuario user, required CartModel cart, required Ubicacion location}) async {
    final response = await _post('/pedidos', {}); // Placeholder
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidos(int idUsuario) async {
    final data = await _get('/pedidos/cliente/$idUsuario');
    return data.map((item) => Pedido.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) async {
    final data = await _getMap('/pedidos/$idPedido');
    return PedidoDetalle.fromMap(data);
  }

  @override
  Future<List<Pedido>> getPedidosPorEstado(String estado) async {
    final data = await _get('/pedidos/estado/$estado');
    return data.map((item) => Pedido.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) async {
    final response = await _put('/pedidos/$idPedido/estado', {'estado': nuevoEstado});
    return response['success'] ?? false;
  }

  @override
  Future<List<Producto>> getAllProductosAdmin() async {
    final data = await _get('/admin/productos');
    return data.map((item) => Producto.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Producto?> createProducto(Producto producto) async {
    final response = await _post('/admin/productos', producto.toMap());
    return Producto.fromMap(response['producto'] as Map<String, dynamic>);
  }

  @override
  Future<bool> updateProducto(Producto producto) async {
    final response = await _put('/admin/productos/${producto.idProducto}', producto.toMap());
    return response['success'] ?? false;
  }

  @override
  Future<bool> deleteProducto(int idProducto) async {
    // Implementación placeholder
    return true;
  }

  @override
  Future<Map<String, dynamic>> getAdminStats() async {
    return await _getMap('/admin/stats');
  }

  @override
  Future<List<Pedido>> getPedidosDisponibles() async {
    final data = await _get('/pedidos/disponibles');
    return data.map((item) => Pedido.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> asignarPedido(int idPedido, int idDelivery) async {
    final response = await _put('/pedidos/$idPedido/asignar', {'id_delivery': idDelivery});
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) async {
    final data = await _get('/pedidos/delivery/$idDelivery');
    return data.map((item) => Pedido.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Map<String, dynamic>> getDeliveryStats(int idDelivery) async {
    return await _getMap('/delivery/stats/$idDelivery');
  }

  @override
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon) async {
    final response = await _put('/repartidor/$idRepartidor/ubicacion', {'latitud': lat, 'longitud': lon});
    return response['success'] ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) async {
    final data = await _getMap('/pedidos/$idPedido/tracking');
    return data['ubicacion'] as Map<String, dynamic>?;
  }

  @override
  Future<int?> iniciarConversacion({required int idCliente, int? idDelivery, int? idAdminSoporte, int? idPedido}) async {
    final response = await _post('/chat/iniciar', {});
    return response['id_conversacion'] as int?;
  }

  @override
  Future<List<ChatConversation>> getConversaciones(int idUsuario) async {
    final data = await _get('/chat/conversaciones/$idUsuario');
    return data.map((item) => ChatConversation.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ChatMessage>> getMensajesDeConversacion(int idConversacion) async {
    final data = await _get('/chat/conversaciones/$idConversacion/mensajes');
    return data.map((item) => ChatMessage.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> enviarMensaje({required int idConversacion, required int idRemitente, required String mensaje}) async {
    final response = await _post('/chat/mensajes', {});
    return response['success'] ?? false;
  }
}
