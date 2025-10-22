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
import 'data_source.dart';

class ApiDataSource implements DataSource {
  final String _baseUrl = AppConfig.baseUrl;

  // --- Métodos HTTP Helper ---
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 POST: $url');
    debugPrint('   -> Body: ${jsonEncode(data)}'); // Log encoded body
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(data),
      );
      if (response.body.isEmpty) return {"success": true}; // Handle 204 No Content
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      debugPrint('   <- Response [${response.statusCode}]: $decodedBody'); // Log response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedBody;
      } else {
        throw HttpException(decodedBody['message'] ?? 'Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      debugPrint('   <- Error: SocketException (No connection)');
      throw const SocketException('No se pudo conectar al servidor.');
    } on FormatException {
      debugPrint('   <- Error: FormatException (Invalid JSON)');
      throw const FormatException('Respuesta inesperada del servidor.');
    } catch (e) {
      debugPrint('   <- Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 PUT: $url');
    debugPrint('   -> Body: ${jsonEncode(data)}');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(data),
      );
      if (response.body.isEmpty) return {"success": true};
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      debugPrint('   <- Response [${response.statusCode}]: $decodedBody');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedBody;
      } else {
        throw HttpException(decodedBody['message'] ?? 'Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      debugPrint('   <- Error: SocketException (No connection)');
      throw const SocketException('No se pudo conectar al servidor.');
    } on FormatException {
      debugPrint('   <- Error: FormatException (Invalid JSON)');
      throw const FormatException('Respuesta inesperada del servidor.');
    } catch (e) {
      debugPrint('   <- Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🗑️ DELETE: $url');
    try {
      final response = await http.delete(url, headers: {'Content-Type': 'application/json; charset=UTF-8'});
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      debugPrint('   <- Response [${response.statusCode}]: $decodedBody');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedBody;
      } else {
        throw HttpException(decodedBody['message'] ?? 'Error al eliminar: ${response.statusCode}');
      }
    } on SocketException {
      debugPrint('   <- Error: SocketException (No connection)');
      throw const SocketException('No se pudo conectar al servidor.');
    } on FormatException {
      debugPrint('   <- Error: FormatException (Invalid JSON)');
      throw const FormatException('Respuesta inesperada del servidor.');
    } catch (e) {
      debugPrint('   <- Error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> _get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 GET List: $uri');
    try {
      final response = await http.get(uri);
      final decodedBody = utf8.decode(response.bodyBytes);
      debugPrint('   <- Response [${response.statusCode}]: (List data)'); // Avoid logging potentially large lists
      if (response.statusCode == 200) {
        return jsonDecode(decodedBody) as List<dynamic>;
      } else {
        final errorBody = jsonDecode(decodedBody);
        throw HttpException(errorBody['message'] ?? 'Error del servidor al obtener datos: ${response.statusCode}');
      }
    } on SocketException {
      debugPrint('   <- Error: SocketException (No connection)');
      throw const SocketException('No se pudo conectar al servidor.');
    } on FormatException {
      debugPrint('   <- Error: FormatException (Invalid JSON)');
      throw const FormatException('Respuesta inesperada del servidor.');
    } catch (e) {
      debugPrint('   <- Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getMap(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🌍 GET Map: $url');
    try {
      final response = await http.get(url);
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      debugPrint('   <- Response [${response.statusCode}]: $data');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        throw HttpException(data['message'] ?? 'Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      debugPrint('   <- Error: SocketException (No connection)');
      throw const SocketException('No se pudo conectar al servidor.');
    } on FormatException {
      debugPrint('   <- Error: FormatException (Invalid JSON)');
      throw const FormatException('Respuesta inesperada del servidor.');
    } catch (e) {
      debugPrint('   <- Error: $e');
      rethrow;
    }
  }

  // --- Implementaciones ---
  @override
  Future<Usuario?> login(String email, String password) async {
    final response = await _post('/login', {'correo': email, 'contrasena': password});
    if (response['success'] == true && response['usuario'] != null) {
      return Usuario.fromMap(response['usuario']);
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
    return data.map((item) => Producto.fromMap(item)).toList();
  }

  @override
  Future<List<Producto>> getAllProductosAdmin() async {
    final data = await _get('/admin/productos');
    return data.map((item) => Producto.fromMap(item)).toList();
  }

  @override
  Future<Producto?> createProducto(Producto producto) async {
    final response = await _post('/admin/productos', producto.toMap());
    if (response['success'] == true && response['producto'] != null) {
      return Producto.fromMap(response['producto']);
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
    return data.map((item) => ProductoRankeado.fromMap(item)).toList();
  }
  // --- NUEVO MÉTODO PARA AÑADIR RECOMENDACIÓN ---
  @override
  Future<bool> addRecomendacion({
    required int idProducto,
    required int idUsuario,
    required int puntuacion,
    String? comentario,
  }) async {
    try {
      final response = await _post('/productos/$idProducto/recomendaciones', {
        'idUsuario': idUsuario,
        'puntuacion': puntuacion,
        'comentario': comentario ?? '', // Enviar vacío si es nulo
      });
      return response['success'] ?? false;
    } catch (e) {
      debugPrint('Error al enviar recomendación: $e');
      return false;
    }
  }

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) async {
    final data = await _get('/ubicaciones/usuario/$idUsuario');
    return data.map((item) => Ubicacion.fromMap(item)).toList();
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

    final response = await _post('/pedidos', {
      'id_cliente': user.idUsuario,
      'id_ubicacion': location.id,
      'total': total,
      'metodo_pago': 'efectivo',
      'productos': productosJson,
    });
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidos(int idUsuario) async {
    final data = await _get('/pedidos/cliente/$idUsuario');
    return data.map((item) => Pedido.fromMap(item)).toList();
  }

  @override
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) async {
    try {
      final data = await _getMap('/pedidos/$idPedido');
      // Asegúrate que la respuesta contiene las claves esperadas antes de parsear
      if (data.containsKey('pedido') && data.containsKey('detalles')) {
        return PedidoDetalle.fromMap(data);
      }
      debugPrint("Respuesta de getPedidoDetalle no tiene la estructura esperada: $data");
      return null;
    } catch (e) {
      debugPrint("Error fetching order details: $e");
      return null;
    }
  }

  @override
  Future<List<Pedido>> getPedidosPorEstado(String estado) async {
    final data = await _get('/pedidos/estado/$estado');
    return data.map((item) => Pedido.fromMap(item)).toList();
  }

  @override
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) async {
    final response = await _put('/pedidos/$idPedido/estado', {'estado': nuevoEstado});
    return response['success'] ?? false;
  }

  // --- NUEVO MÉTODO IMPLEMENTADO ---
  @override
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final data = await _getMap('/admin/stats');
      // Devuelve el mapa completo si la llamada fue exitosa
      // El widget se encargará de verificar la clave 'success'
      return data;
    } catch (e) {
      debugPrint("Error fetching admin stats: $e");
      // Devuelve un mapa indicando el error
      return {"success": false, "error": e.toString()};
    }
  }

  @override
  Future<List<Pedido>> getPedidosDisponibles() async {
    final data = await _get('/pedidos/disponibles');
    return data.map((item) => Pedido.fromMap(item)).toList();
  }

  @override
  Future<bool> asignarPedido(int idPedido, int idDelivery) async {
    final response = await _put('/pedidos/$idPedido/asignar', {'id_delivery': idDelivery});
    return response['success'] ?? false;
  }

  @override
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) async {
    final data = await _get('/pedidos/delivery/$idDelivery');
    return data.map((item) => Pedido.fromMap(item)).toList();
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
        return data['ubicacion'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching tracking data: $e");
      return null;
    }
  }
}

