import 'package:flutter_application_2/models/cart_model.dart';
import 'package:flutter_application_2/models/pedido.dart';
import 'package:flutter_application_2/models/pedido_detalle.dart';
import 'package:flutter_application_2/models/producto.dart';
import '../models/usuario.dart';
import '../models/ubicacion.dart';
import 'api_data_source.dart';
import 'data_source.dart';

/// CLASE DE SERVICIO ÚNICA PARA INYECTAR CON PROVIDER.
class DatabaseService {
  final DataSource _dataSource;
  DatabaseService() : _dataSource = ApiDataSource();

  // --- Métodos de Usuario ---
  Future<Usuario?> login(String email, String password) => _dataSource.login(email, password);
  Future<bool> register(String nombre, String email, String password, String telefono) => _dataSource.register(nombre, email, password, telefono);

  // --- Métodos del Cliente ---
  // CORREGIDO: Se pasan los parámetros nombrados
  Future<List<Producto>> getProductos({String? query, String? categoria}) =>
      _dataSource.getProductos(query: query, categoria: categoria);

  Future<List<Ubicacion>> getUbicaciones(int idUsuario) => _dataSource.getUbicaciones(idUsuario);
  Future<List<ProductoRankeado>> getRecomendaciones() => _dataSource.getRecomendaciones();
  Future<bool> addRecomendacion({ // <-- AÑADIDO
    required int idProducto,
    required int idUsuario,
    required int puntuacion,
    String? comentario,
  }) => _dataSource.addRecomendacion(
        idProducto: idProducto,
        idUsuario: idUsuario,
        puntuacion: puntuacion,
        comentario: comentario,
      );

  Future<bool> placeOrder({
    required Usuario user,
    required CartModel cart,
    required Ubicacion location,
  }) =>
      _dataSource.placeOrder(user: user, cart: cart, location: location);
  Future<List<Pedido>> getPedidos(int idUsuario) => _dataSource.getPedidos(idUsuario);
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) => _dataSource.getPedidoDetalle(idPedido);

  // --- Métodos de Administración ---
  Future<List<Pedido>> getPedidosPorEstado(String estado) => _dataSource.getPedidosPorEstado(estado);
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) => _dataSource.updatePedidoEstado(idPedido, nuevoEstado);
  Future<List<Producto>> getAllProductosAdmin() => _dataSource.getAllProductosAdmin();
  Future<Producto?> createProducto(Producto producto) => _dataSource.createProducto(producto);
  Future<bool> updateProducto(Producto producto) => _dataSource.updateProducto(producto);
  Future<bool> deleteProducto(int idProducto) => _dataSource.deleteProducto(idProducto);
  Future<Map<String, dynamic>> getAdminStats() => _dataSource.getAdminStats();
  // --- MÉTODOS DE DELIVERY AÑADIDOS ---
  Future<List<Pedido>> getPedidosDisponibles() => _dataSource.getPedidosDisponibles();
  Future<bool> asignarPedido(int idPedido, int idDelivery) => _dataSource.asignarPedido(idPedido, idDelivery);
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) => _dataSource.getPedidosPorDelivery(idDelivery);

  // --- MÉTODOS DE TRACKING (LOS QUE FALTABAN) ---
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon) =>
      _dataSource.updateRepartidorLocation(idRepartidor, lat, lon);

  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) =>
      _dataSource.getRepartidorLocation(idPedido);




}

