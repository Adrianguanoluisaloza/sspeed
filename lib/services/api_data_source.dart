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
  String? _authToken;

  ApiDataSource({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Normalizamos la URL base una única vez para evitar dobles barras cuando
  /// el valor viene con o sin `/` al final (caso frecuente al usar túneles o IPs LAN).
  late final String _normalizedBaseUrl =
      _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> get _jsonHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_authToken!}';
    }
    return headers;
  }

  @override
  void setAuthToken(String? token) {
    // Comentario: el backend V3 utiliza JWT; limpiamos espacios para evitar fallos.
    final trimmed = token?.trim();
    _authToken = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final normalizedEndpoint =
        endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$_normalizedBaseUrl$normalizedEndpoint');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    // Comentario: centralizamos la normalización de queryParams para que todos
    // los fallbacks usen exactamente la misma firma de URL sin duplicar lógica.
    final cleaned = queryParameters.map(
      (key, value) => MapEntry(key, value.trim()),
    );
    return uri.replace(queryParameters: cleaned);
  }

  bool _shouldTryAlternateEndpoint(ApiException error) {
    final code = error.statusCode;
    if (code == null) return false;
    // Comentario: solo repetimos la petición con otra ruta cuando la API
    // responde que el recurso no existe o no permite el método usado.
    return code == 404 || code == 405;
  }

  Future<T> _tryEndpoints<T>(
    List<String> endpoints,
    Future<T> Function(String endpoint) request,
  ) async {
    ApiException? lastApiError;
    for (final endpoint in endpoints) {
      try {
        return await request(endpoint);
      } on ApiException catch (error) {
        lastApiError = error;
        if (!_shouldTryAlternateEndpoint(error)) {
          rethrow;
        }
      }
    }
    throw lastApiError ??
        const ApiException('No se pudo completar la solicitud a la API.');
  }

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
    final url = _buildUri(endpoint);
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
    final url = _buildUri(endpoint);
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
    final url = _buildUri(endpoint);
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

  Future<List<dynamic>> _get(String endpoint,
      {Map<String, String>? queryParameters}) async {
    final uri = _buildUri(endpoint, queryParameters);
    debugPrint('🌍 GET List: $uri');
    try {
      final response =
          await _httpClient.get(uri, headers: _jsonHeaders).timeout(_timeout);
      return _parseListResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  Future<Map<String, dynamic>> _getMap(String endpoint,
      {Map<String, String>? queryParameters}) async {
    final url = _buildUri(endpoint, queryParameters);
    debugPrint('🌍 GET Map: $url');
    try {
      final response =
          await _httpClient.get(url, headers: _jsonHeaders).timeout(_timeout);
      return _parseMapResponse(response);
    } catch (error) {
      debugPrint('   <- Error: $error');
      throw _mapToApiException(error);
    }
  }

  // --- Implementaciones ---
  @override
  Future<Usuario?> login(String email, String password) async {
    final payload = {
      'correo': email,
      'email': email,
      'usuario': email,
      'contrasena': password,
      'password': password,
    };
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/login', '/api/login', '/usuarios/login'],
      (endpoint) => _post(endpoint, payload),
    );
    if (response['success'] == false) {
      return null;
    }

    final tokenCandidate = response['token'] ??
        response['access_token'] ??
        response['jwt'] ??
        (response['usuario'] is Map
            ? (response['usuario'] as Map)['token']
            : null);
    if (tokenCandidate is String && tokenCandidate.isNotEmpty) {
      setAuthToken(tokenCandidate);
    }

    final dynamic rawUser =
        response['usuario'] ?? response['user'] ?? response['data'];

    Map<String, dynamic>? userMap;
    if (rawUser is Map) {
      userMap = Map<String, dynamic>.from(rawUser as Map);
    } else if (response.containsKey('id_usuario') ||
        response.containsKey('idUsuario')) {
      userMap = Map<String, dynamic>.from(response);
    }

    if (_authToken != null && _authToken!.isNotEmpty) {
      userMap ??= <String, dynamic>{};
      userMap['token'] ??= _authToken;
    }

    if (userMap != null && userMap.isNotEmpty) {
      return Usuario.fromMap(userMap);
    }
    return null;
  }

  @override
  Future<bool> register(String name, String email, String password, String phone) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/registro', '/register', '/usuarios'],
      (endpoint) => _post(endpoint, {
            'nombre': name,
            'correo': email,
            'email': email,
            'contrasena': password,
            'password': password,
            'telefono': phone,
            'phone': phone,
          }),
    );
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
  Future<Usuario?> updateUsuario(Usuario usuario) async {
    final payload = usuario.toMap()
      ..remove('contrasena'); // Comentario: evitamos sobrescribir contraseñas accidentales.
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/usuario/${usuario.idUsuario}', '/api/usuario/${usuario.idUsuario}'],
      (endpoint) => _put(endpoint, payload),
    );
    final dynamic rawUser =
        response['usuario'] ?? response['data'] ?? response['user'];
    Map<String, dynamic>? userMap;
    if (rawUser is Map) {
      userMap = Map<String, dynamic>.from(rawUser as Map);
    }
    if (userMap == null || userMap.isEmpty) {
      return null;
    }
    if (_authToken != null && _authToken!.isNotEmpty) {
      userMap['token'] ??= _authToken;
    }
    return Usuario.fromMap(userMap);
  }

  @override
  Future<List<Producto>> getProductos({String? query, String? categoria}) async {
    final queryParams = <String, String>{};
    if (query != null && query.isNotEmpty) queryParams['q'] = query;
    if (categoria != null && categoria.isNotEmpty) {
      queryParams['categoria'] = categoria;
    }
    final endpoints = ['/productos', '/api/productos', '/productos/listar'];
    final data = await _tryEndpoints<List<dynamic>>(
      endpoints,
      (endpoint) => _get(endpoint,
          queryParameters: queryParams.isEmpty ? null : queryParams),
    );
    return data
        .map((item) => Producto.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<List<Producto>> getAllProductosAdmin() async {
    final data = await _tryEndpoints<List<dynamic>>(
      ['/admin/productos', '/api/admin/productos'],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) => Producto.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<Producto?> createProducto(Producto producto) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/admin/productos', '/api/admin/productos'],
      (endpoint) => _post(endpoint, producto.toMap()),
    );
    if (response['success'] == true && response['producto'] != null) {
      return Producto.fromMap(
        Map<String, dynamic>.from(response['producto'] as Map),
      );
    }
    return null;
  }

  @override
  Future<bool> updateProducto(Producto producto) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/admin/productos/${producto.idProducto}',
        '/api/admin/productos/${producto.idProducto}'],
      (endpoint) => _put(endpoint, producto.toMap()),
    );
    return response['success'] ?? false;
  }

  @override
  Future<bool> deleteProducto(int idProducto) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/admin/productos/$idProducto', '/api/admin/productos/$idProducto'],
      (endpoint) => _delete(endpoint),
    );
    return response['success'] ?? false;
  }
  @override
  Future<List<ProductoRankeado>> getRecomendaciones() async {
    final data = await _tryEndpoints<List<dynamic>>(
      ['/recomendaciones', '/api/recomendaciones'],
      (endpoint) => _get(endpoint),
    );
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
    final response = await _tryEndpoints<Map<String, dynamic>>(
      [
        '/productos/$idProducto/recomendaciones',
        '/api/productos/$idProducto/recomendaciones',
      ],
      (endpoint) => _post(endpoint, {
            'id_usuario': idUsuario,
            'usuario_id': idUsuario,
            'puntuacion': puntuacion,
            'rating': puntuacion,
            'comentario': comentario ?? '',
            'comment': comentario ?? '',
          }),
    );
    return response['success'] ?? false;
  }

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) async {
    final data = await _tryEndpoints<List<dynamic>>(
      [
        '/ubicaciones/usuario/$idUsuario',
        '/api/ubicaciones/usuario/$idUsuario',
      ],
      (endpoint) => _get(endpoint),
    );
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

    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/pedidos', '/api/pedidos'],
      (endpoint) => _post(endpoint, {
            ...payload,
            // Comentario: replicamos la estructura esperada por posibles backends
            // alternos que usan claves diferentes para los detalles del carrito.
            'items': productosJson,
            'detalles': productosJson,
          }),
    );
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidos(int idUsuario) async {
    final data = await _tryEndpoints<List<dynamic>>(
      [
        '/pedidos/cliente/$idUsuario',
        '/api/pedidos/cliente/$idUsuario',
      ],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) async {
    final data = await _tryEndpoints<Map<String, dynamic>>(
      ['/pedidos/$idPedido', '/api/pedidos/$idPedido'],
      (endpoint) => _getMap(endpoint),
    );
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
    final data = await _tryEndpoints<List<dynamic>>(
      [
        '/pedidos/estado/$estado',
        '/api/pedidos/estado/$estado',
      ],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      [
        '/pedidos/$idPedido/estado',
        '/api/pedidos/$idPedido/estado',
      ],
      (endpoint) => _put(endpoint, {'estado': nuevoEstado}),
    );
    return response['success'] ?? false;
  }

  // --- NUEVO MÉTODO IMPLEMENTADO ---
  @override
  Future<Map<String, dynamic>> getAdminStats() async =>
      _tryEndpoints<Map<String, dynamic>>(
        ['/admin/stats', '/api/admin/stats'],
        (endpoint) => _getMap(endpoint),
      );

  @override
  Future<List<Pedido>> getPedidosDisponibles() async {
    final data = await _tryEndpoints<List<dynamic>>(
      ['/pedidos/disponibles', '/api/pedidos/disponibles'],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> asignarPedido(int idPedido, int idDelivery) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      [
        '/pedidos/$idPedido/asignar',
        '/api/pedidos/$idPedido/asignar',
      ],
      (endpoint) => _put(endpoint, {'id_delivery': idDelivery, 'delivery_id': idDelivery}),
    );
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) async {
    final data = await _tryEndpoints<List<dynamic>>(
      [
        '/pedidos/delivery/$idDelivery',
        '/api/pedidos/delivery/$idDelivery',
      ],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) => Pedido.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon) async {
    try {
      final payload = {
        'latitud': lat,
        'longitud': lon,
        'latitud_actual': lat,
        'longitud_actual': lon,
      };
      final response = await _tryEndpoints<Map<String, dynamic>>(
        [
          '/repartidor/$idRepartidor/ubicacion',
          '/delivery/$idRepartidor/ubicacion',
          '/api/delivery/$idRepartidor/ubicacion',
        ],
        (endpoint) => _put(endpoint, payload),
      );
      return response['success'] ?? true;
    } catch (e) {
      debugPrint('Error al actualizar ubicación: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) async {
    try {
      final data = await _tryEndpoints<Map<String, dynamic>>(
        [
          '/pedidos/$idPedido/tracking',
          '/pedidos/$idPedido/seguimiento',
          '/api/pedidos/$idPedido/tracking',
        ],
        (endpoint) => _getMap(endpoint),
      );
      if (data['success'] == true && data['ubicacion'] != null) {
        return Map<String, dynamic>.from(data['ubicacion'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching tracking data: $e");
      return null;
    }
  }

  @override
  Future<int?> iniciarConversacion({
    required int idCliente,
    int? idDelivery,
    int? idAdminSoporte,
    int? idPedido,
  }) async {
    final payload = {
      'id_cliente': idCliente,
      'id_delivery': idDelivery,
      'id_admin_soporte': idAdminSoporte,
      'id_pedido': idPedido,
    }..removeWhere((key, value) => value == null);

    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/chat/iniciar', '/api/chat/iniciar'],
      (endpoint) => _post(endpoint, payload),
    );
    final dynamic idValue =
        response['id_conversacion'] ?? response['conversationId'] ?? response['id'];
    if (idValue is int) return idValue;
    if (idValue is String) return int.tryParse(idValue);
    return null;
  }

  @override
  Future<List<ChatConversation>> getConversaciones(int idUsuario) async {
    final data = await _tryEndpoints<List<dynamic>>(
      [
        '/chat/conversaciones/$idUsuario',
        '/api/chat/conversaciones/$idUsuario',
      ],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) =>
            ChatConversation.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<List<ChatMessage>> getMensajesDeConversacion(int idConversacion) async {
    final data = await _tryEndpoints<List<dynamic>>(
      [
        '/chat/mensajes/$idConversacion',
        '/api/chat/mensajes/$idConversacion',
      ],
      (endpoint) => _get(endpoint),
    );
    return data
        .map((item) => ChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<bool> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String mensaje,
  }) async {
    final response = await _tryEndpoints<Map<String, dynamic>>(
      ['/chat/mensajes', '/api/chat/mensajes'],
      (endpoint) => _post(endpoint, {
            'id_conversacion': idConversacion,
            'id_remitente': idRemitente,
            'mensaje': mensaje,
          }),
    );
    final success = response['success'];
    if (success is bool) return success;
    final status = response['status']?.toString().toLowerCase();
    return status == 'ok' || status == 'success';
  }
}

