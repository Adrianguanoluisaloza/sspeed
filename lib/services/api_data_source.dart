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
import '../models/tracking_point.dart';
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

  ApiDataSource({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  void setAuthToken(String? token) {
    _token = token;
    debugPrint('[ApiDataSource] Token actualizado: \x1B[33m$_token\x1B[0m');
  }

  Map<String, String> get _jsonHeaders {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    // CORRECCIÓN: Se añade la cabecera para evitar la página de advertencia de Ngrok.
    headers['ngrok-skip-browser-warning'] = 'true';

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static const Duration _timeout = Duration(seconds: 15);

  bool _looksLikeJson(String? body) {
    if (body == null) return false;
    final trimmed = body.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  Future<Map<String, dynamic>> _parseMapResponse(http.Response response) async {
    final bodyString =
        response.bodyBytes.isEmpty ? null : utf8.decode(response.bodyBytes);

    if (bodyString != null && !_looksLikeJson(bodyString)) {
      debugPrint('   <- Response [${response.statusCode}]: $bodyString');
      throw ApiException(
        'Respuesta inesperada del servidor (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final raw = bodyString == null ? null : jsonDecode(bodyString);
    debugPrint('   <- Response [${response.statusCode}]: $raw');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (raw == null) {
        return {'success': true};
      }
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is List<dynamic>) {
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

  Future<List<dynamic>> _parseListResponse(http.Response response) async {
    final bodyString =
        response.bodyBytes.isEmpty ? null : utf8.decode(response.bodyBytes);

    if (bodyString != null && !_looksLikeJson(bodyString)) {
      debugPrint('   <- Response [${response.statusCode}]: $bodyString');
      throw ApiException(
        'Respuesta inesperada del servidor (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final raw = bodyString == null ? [] : jsonDecode(bodyString);
    debugPrint('   <- Response [${response.statusCode}]: (list)');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (raw is List<dynamic>) {
        return raw;
      }
      if (raw is Map<String, dynamic>) {
        const keys = [
          'data',
          'productos',
          'items',
          'pedidos',
          'ubicaciones',
          'detalles',
          'results',
          'usuarios',
          'recomendaciones',
          'conversaciones',
          'mensajes'
        ];
        for (final key in keys) {
          if (raw.containsKey(key) && raw[key] is List<dynamic>) {
            return raw[key];
          }
        }
      }
      throw const ApiException('Formato de lista no valido.');
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
      return const ApiException(
          'Tiempo de espera agotado, intenta nuevamente.');
    }
    if (error is FormatException) {
      return const ApiException('Respuesta inesperada del servidor.');
    }
    return ApiException(error.toString());
  }

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('API POST: $url');
    debugPrint('   -> Payload: ${jsonEncode(data)}');
    try {
      final response = await _httpClient
          .post(url, headers: _jsonHeaders, body: jsonEncode(data))
          .timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  Future<Map<String, dynamic>> _put(
      String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('API PUT: $url');
    debugPrint('   -> Payload: ${jsonEncode(data)}');
    try {
      final response = await _httpClient
          .put(url, headers: _jsonHeaders, body: jsonEncode(data))
          .timeout(_timeout);
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
      final response =
          await _httpClient.get(uri, headers: _jsonHeaders).timeout(_timeout);
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
      final response =
          await _httpClient.get(url, headers: _jsonHeaders).timeout(_timeout);
      return await _parseMapResponse(response);
    } catch (e) {
      debugPrint('   <- Error: $e');
      throw _mapToApiException(e);
    }
  }

  // --- IMPLEMENTACIONES ---

  @override
  Future<Usuario?> login(String email, String password) async {
    final response =
        await _post('/login', {'correo': email, 'contrasena': password});
    final rawUser = response['usuario'] ?? response['user'] ?? response['data'];
    if (rawUser is Map<String, dynamic>) {
      return Usuario.fromMap(rawUser);
    }
    return null;
  }

  @override
  Future<bool> register(String name, String email, String password,
      String phone, String rol) async {
    final normalizedRole = {
          'cliente': 'cliente',
          // Compatibilidad: el backend espera 'repartidor' en /registro
          'delivery': 'repartidor',
          'repartidor': 'repartidor',
          'admin': 'admin',
          'soporte': 'soporte',
        }[rol.trim().toLowerCase()] ??
        'cliente';
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
    final response =
        await _put('/usuarios/${usuario.idUsuario}', usuario.toMap());

    if (response['success'] == true) {
      final userMap = response['usuario'] as Map<String, dynamic>? ?? response;
      return Usuario.fromMap(userMap);
    }

    return null;
  }

  @override
  Future<Usuario?> getUsuarioById(int idUsuario) async {
    final data = await _getMap('/usuarios/$idUsuario');
    final rawUser = data['usuario'] ?? data['user'] ?? data['data'] ?? data;
    return rawUser is Map<String, dynamic> ? Usuario.fromMap(rawUser) : null;
  }

  @override
  Future<List<Producto>> getProductos(
      {String? query, String? categoria}) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    if (categoria != null && categoria.isNotEmpty) {
      params['categoria'] = categoria;
    }

    final uri = params.isEmpty
        ? Uri.parse('$_baseUrl/productos')
        : Uri.parse('$_baseUrl/productos').replace(queryParameters: params);
    final response =
        await _httpClient.get(uri, headers: _jsonHeaders).timeout(_timeout);
    final data = await _parseListResponse(response);
    return data
        .map((item) => Producto.fromMap(item as Map<String, dynamic>))
        .toList();
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
    final data = response['data'];
    if (data == null) {
      return null;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    // Backend devuelve JSON (String) crudo de Google Geocoding API
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          final results = decoded['results'];
          if (results is List && results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final geom = first['geometry'] as Map<String, dynamic>?;
            final loc =
                geom != null ? geom['location'] as Map<String, dynamic>? : null;
            final lat = loc != null ? (loc['lat'] as num?)?.toDouble() : null;
            final lng = loc != null ? (loc['lng'] as num?)?.toDouble() : null;
            final formatted = first['formatted_address']?.toString();
            if (lat != null && lng != null) {
              return {
                'latitud': lat,
                'longitud': lng,
                'direccion': formatted ?? direccion,
              };
            }
          }
        }
      } catch (_) {/* ignora y cae al null */}
    }
    return null;
  }

  @override
  Future<List<ProductoRankeado>> getRecomendaciones() async {
    try {
      final data = await _get('/recomendaciones/destacadas');
      return data
          .cast<Map<String, dynamic>>()
          .map((item) => ProductoRankeado.fromMap(item))
          .where((p) => p.idProducto > 0)
          .where((p) {
        final n = p.nombre.trim();
        return n.isNotEmpty &&
            n.toLowerCase() != 'producto' &&
            n.toLowerCase() != 'sin nombre';
      }).toList();
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! >= 500) {
        rethrow;
      }
      debugPrint(
          '[ApiDataSource] Recomendaciones destacadas no disponibles (${e.statusCode ?? '-'}): ${e.message}');
      return const <ProductoRankeado>[];
    }
  }

  @override
  Future<RecomendacionesProducto> getRecomendacionesPorProducto(
      int idProducto) async {
    final response = await _getMap('/productos/$idProducto/recomendaciones');
    final raw = response['data'];
    final data = raw is Map<String, dynamic>
        ? raw
        : (raw is Map
            ? raw.cast<String, dynamic>()
            : const <String, dynamic>{});
    return RecomendacionesProducto.fromMap(data);
  }

  @override
  Future<bool> addRecomendacion(
      {required int idProducto,
      required int idUsuario,
      required int puntuacion,
      String? comentario}) async {
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
    final productosJson = cart.items
        .map((item) => {
              'id_producto': item.producto.idProducto,
              'cantidad': item.quantity,
              'precio_unitario': item.producto.precio,
              'subtotal': item.subtotal,
            })
        .toList();

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
    return data
        .map((item) => Pedido.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) async {
    final data = await _getMap('/pedidos/$idPedido');
    // Try to get from 'data' key, otherwise assume the map itself is the pedido data
    final Map<String, dynamic> pedidoData =
        (data['data'] as Map<String, dynamic>?) ?? data;
    return PedidoDetalle.fromMap(pedidoData);
  }

  @override
  Future<List<Pedido>> getPedidosPorEstado(String estado) async {
    final data = await _get('/pedidos/estado/$estado');
    return data
        .map((item) => Pedido.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) async {
    final response =
        await _put('/pedidos/$idPedido/estado', {'estado': nuevoEstado});
    return response['success'] ?? false;
  }

  @override
  Future<List<Producto>> getAllProductosAdmin() async {
    final data = await _get('/admin/productos');
    return data
        .map((item) => Producto.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Producto?> createProducto(Producto producto) async {
    final response = await _post('/admin/productos', producto.toMap());
    return Producto.fromMap(response['producto'] as Map<String, dynamic>);
  }

  @override
  Future<bool> updateProducto(Producto producto) async {
    final response =
        await _put('/admin/productos/${producto.idProducto}', producto.toMap());
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
      final response = await _httpClient
          .delete(url, headers: _jsonHeaders)
          .timeout(_timeout);
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

  // --- Negocios ---
  @override
  Future<List<Usuario>> getNegocios() async {
    final data = await _get('/admin/negocios');
    return data.map((e) => Usuario.fromMap(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Usuario?> createNegocio(Usuario negocio) async {
    final resp = await _post('/admin/negocios', negocio.toMap());
    final m = resp['usuario'] as Map<String, dynamic>? ??
        resp['data'] as Map<String, dynamic>? ??
        resp;
    return Usuario.fromMap(m);
  }

  @override
  Future<Usuario?> getNegocioById(int id) async {
    final m = await _getMap('/admin/negocios/$id');
    final data = m['data'] as Map<String, dynamic>? ?? m;
    return Usuario.fromMap(data);
  }

  @override
  Future<Usuario?> updateNegocio(Usuario negocio) async {
    final m =
        await _put('/admin/negocios/${negocio.idUsuario}', negocio.toMap());
    final data = m['data'] as Map<String, dynamic>? ?? m;
    return Usuario.fromMap(data);
  }

  @override
  Future<List<Producto>> getProductosPorNegocio(int idNegocio) async {
    final data = await _get('/admin/negocios/$idNegocio/productos');
    return data
        .map((e) => Producto.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Producto?> createProductoParaNegocio(
      int idNegocio, Producto producto) async {
    final resp =
        await _post('/admin/negocios/$idNegocio/productos', producto.toMap());
    final m = resp['producto'] as Map<String, dynamic>? ??
        resp['data'] as Map<String, dynamic>? ??
        resp;
    return Producto.fromMap(m);
  }

  @override
  Future<List<Pedido>> getPedidosDisponibles() async {
    final data = await _get('/pedidos/disponibles');
    return data
        .map((item) => Pedido.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> asignarPedido(int idPedido, int idDelivery) async {
    final response =
        await _put('/pedidos/$idPedido/asignar', {'id_delivery': idDelivery});
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) async {
    final data = await _get('/pedidos/delivery/$idDelivery');
    return data
        .map((item) => Pedido.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getDeliveryStats(int idDelivery) async {
    return await _getMap('/delivery/stats/$idDelivery');
  }

  @override
  Future<bool> updateRepartidorLocation(
      int idRepartidor, double lat, double lon) async {
    final response = await _put('/ubicaciones/repartidor/$idRepartidor',
        {'latitud': lat, 'longitud': lon});
    return response['success'] ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) async {
    try {
      final data = await _getMap('/tracking/pedido/$idPedido');
      return data['data'] as Map<String, dynamic>?;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null; // Not found is not an error here.
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRepartidoresLocation(
      List<int> ids) async {
    final response =
        await _post('/tracking/repartidores/ubicaciones', {'ids': ids});
    final data = response['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Future<List<TrackingPoint>> getTrackingRoute(int idPedido) async {
    try {
      final data = await _get('/tracking/pedido/$idPedido/ruta');
      return data
          .map((item) => TrackingPoint.fromMap(item as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<int?> iniciarConversacion(
      {required int idCliente,
      int? idDelivery,
      int? idAdminSoporte,
      int? idPedido}) async {
    final response = await _post(
        '/chat/iniciar',
        {
          'idCliente': idCliente,
          'idDelivery': idDelivery,
          'idAdminSoporte': idAdminSoporte,
          'idPedido': idPedido
        }..removeWhere((key, value) => value == null));
    return response['id_conversacion'] as int?;
  }

  @override
  Future<List<ChatConversation>> getConversaciones(int idUsuario) async {
    final data = await _get('/chat/conversaciones/$idUsuario');
    return data
        .map((item) => ChatConversation.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ChatMessage>> getMensajesDeConversacion(
      int idConversacion) async {
    final data = await _get('/chat/conversaciones/$idConversacion/mensajes');
    return data
        .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String mensaje,
    bool esBot = false,
  }) async {
    if (esBot) {
      return _post('/chat/bot/mensajes', {
        'idConversacion': idConversacion,
        'idRemitente': idRemitente,
        'mensaje': mensaje,
      });
    }

    if (idConversacion <= 0) {
      throw const ApiException('Conversacion no valida para enviar mensajes.');
    }

    return _post(
      '/chat/conversaciones/$idConversacion/mensajes',
      {
        'idRemitente': idRemitente,
        'mensaje': mensaje,
      },
    );
  }
}
