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
import '../models/recomendacion_data.dart';
import '../models/ubicacion.dart';
import '../models/usuario.dart';
import 'api_exception.dart';
import 'data_source.dart';

class ApiDataSource implements DataSource {
  @override
  Future<bool> deleteUbicacion(int id) async {
    final response = await _delete('/ubicaciones/$id');
    return response['success'] ?? false;
  }
  final String _baseUrl = AppConfig.baseUrl;
  final http.Client _httpClient;
  String? _token;

  ApiDataSource({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  void setAuthToken(String? token) {
    _token = token;
    debugPrint('[ApiDataSource] Token actualizado: \x1B[33m$_token\x1B[0m');
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
      throw const ApiException('Formato de lista no valido.');
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
    debugPrint('API POST: $url');
    debugPrint('   -> Payload: ${jsonEncode(data)}');
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
    debugPrint('API PUT: $url');
    debugPrint('   -> Payload: ${jsonEncode(data)}');
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
    debugPrint('API GET List: $uri');
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
    debugPrint('API GET Map: $url');
    try {
      final response = await _httpClient.get(url, headers: _jsonHeaders).timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // --- IMPLEMENTACIONES ---

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
  Future<bool> register(String name, String email, String password, String phone, String rol) async {
    final normalizedRole = {
      'cliente': 'cliente',
      'delivery': 'delivery',
      'repartidor': 'delivery',
      'admin': 'admin',
      'soporte': 'soporte',
    }[rol.trim().toLowerCase()] ?? 'cliente';
    final response = await _post('/registro', {
      'nombre': name,
      'correo': email,
      'contrasena': password,
      'telefono': phone,
      'rol': normalizedRole,
    });
    return response['success'] ?? false;
  }

  @override
  Future<Usuario?> updateUsuario(Usuario usuario) async {
    final response = await _put('/usuarios/${usuario.idUsuario}', usuario.toMap());

    if (response['success'] == true) {
      final userMap = response['usuario'] as Map<String, dynamic>? ?? response;
      return Usuario.fromMap(userMap);
    }

    return null;
  }

  @override
  Future<List<Producto>> getProductos({String? query, String? categoria}) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (categoria != null && categoria.isNotEmpty) params['categoria'] = categoria;

    final uri = params.isEmpty ? Uri.parse('$_baseUrl/productos') : Uri.parse('$_baseUrl/productos').replace(queryParameters: params);
    final response = await _httpClient.get(uri, headers: _jsonHeaders).timeout(_timeout);
    final data = await _parseListResponse(response);
    return data.map((item) => Producto.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Producto?> getProductoById(int id) async {
    final data = await _getMap('/productos/$id');
    return Producto.fromMap(data);
  }

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) async {
    // CORRECCIÓN: Se utiliza la ruta correcta definida en la API de Java.
    final data = await _get('/ubicaciones/usuario/$idUsuario');
    return data.cast<Map<String, dynamic>>().map(Ubicacion.fromMap).toList();
  }

  @override
  Future<void> guardarUbicacion(Ubicacion ubicacion) async {
    await _post('/ubicaciones', ubicacion.toMap());
  }

  @override
  Future<Map<String, dynamic>?> geocodificarDireccion(String direccion) async {
    final response = await _post('/geocodificar', {'direccion': direccion});
    return response['data'] as Map<String, dynamic>?;
  }

  @override
  Future<List<ProductoRankeado>> getRecomendaciones() async {
    final data = await _get('/recomendaciones');
    final Map<int, _ProductoRating> acumulados = {};

    for (final item in data.cast<Map<String, dynamic>>()) {
      final idProducto = _asInt(item['id_producto']);
      if (idProducto == 0) continue;

      final nombre = (item['producto'] ?? item['nombre'] ?? 'Producto').toString();
      final rating = _asDouble(item['rating'] ?? item['puntuacion']);

      final acumulado = acumulados.putIfAbsent(idProducto, () => _ProductoRating(nombre));
      acumulado.add(rating);
    }

    final recomendados = acumulados.entries
        .map((entry) => ProductoRankeado(
              idProducto: entry.key,
              nombre: entry.value.nombre,
              ratingPromedio: entry.value.promedio,
              totalReviews: entry.value.cantidad,
            ))
        .toList();

    recomendados.sort((a, b) {
      final ratingDiff = b.ratingPromedio.compareTo(a.ratingPromedio);
      if (ratingDiff != 0) return ratingDiff;
      return b.totalReviews.compareTo(a.totalReviews);
    });

    return recomendados;
  }

  @override
  Future<RecomendacionesProducto> getRecomendacionesPorProducto(int idProducto) async {
    final data = await _get('/recomendaciones');
    final List<Recomendacion> resenas = [];
    double suma = 0;

    for (final item in data.cast<Map<String, dynamic>>()) {
      if (_asInt(item['id_producto']) != idProducto) continue;

      final recomendacion = Recomendacion.fromMap(item);
      resenas.add(recomendacion);
      suma += recomendacion.puntuacion.toDouble();
    }

    final promedio = resenas.isEmpty ? 0.0 : suma / resenas.length;
    final resumen = RecomendacionResumen(ratingPromedio: promedio, totalResenas: resenas.length);

    return RecomendacionesProducto(resumen: resumen, recomendaciones: resenas);
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
  Future<bool> placeOrder({
    required Usuario user,
    required CartModel cart,
    required Ubicacion location,
    required String paymentMethod,
  }) async {
    const double shippingCost = 2.00;
    final double total = cart.total + shippingCost;
    final productosJson = cart.items.map((item) => {
      'id_producto': item.producto.idProducto,
      'cantidad': item.quantity,
      'precio_unitario': item.producto.precio,
      'subtotal': item.subtotal,
    }).toList();

    final payload = {
      'id_cliente': user.idUsuario,
      'id_ubicacion': location.id,
      'direccion_entrega': location.direccion,
      'metodo_pago': paymentMethod,
      'estado': 'pendiente',
      'total': total,
      'productos': productosJson,
    };

    final response = await _post('/pedidos', payload);
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
    final pedidoData = data['data'] as Map<String, dynamic>?;
    return pedidoData != null ? PedidoDetalle.fromMap(pedidoData) : null;
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
    final response = await _delete('/admin/productos/$idProducto');
    return response['success'] ?? false;
  }

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('API DELETE: $url');
    try {
      final response = await _httpClient.delete(url, headers: _jsonHeaders).timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
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
    final response = await _put('/delivery/$idRepartidor/ubicacion', {'latitud': lat, 'longitud': lon});
    return response['success'] ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) async {
    try {
      final data = await _getMap('/pedidos/$idPedido/tracking');
      return data['data'] as Map<String, dynamic>?;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null; // Not found is not an error here.
      rethrow;
    }
  }

  @override
  Future<int?> iniciarConversacion({required int idCliente, int? idDelivery, int? idAdminSoporte, int? idPedido}) async {
    final response = await _post('/chat/iniciar', {
      'idCliente': idCliente, 'idDelivery': idDelivery, 'idAdminSoporte': idAdminSoporte, 'idPedido': idPedido
    }..removeWhere((key, value) => value == null));
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
  Future<bool> enviarMensaje({required int idConversacion, required int idRemitente, required String mensaje, bool isBot = false}) async {
    // Si es un chat con el bot, la URL es diferente y maneja la respuesta del bot.
    final endpoint = isBot ? '/chat/bot/mensajes' : '/chat/mensajes';
    final response = await _post(endpoint, {
      'idConversacion': idConversacion,
      'idRemitente': idRemitente,
      'mensaje': mensaje,
    });
    return response['success'] ?? false;
  }
}


class _ProductoRating {
  _ProductoRating(this.nombre);

  final String nombre;
  double _acumulado = 0;
  int _cantidad = 0;

  void add(double rating) {
    _acumulado += rating;
    _cantidad++;
  }

  double get promedio => _cantidad == 0 ? 0.0 : _acumulado / _cantidad;
  int get cantidad => _cantidad;
}
