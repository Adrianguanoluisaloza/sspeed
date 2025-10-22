import '../models/cart_model.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../models/ubicacion.dart';

/// Define el contrato que nuestra fuente de datos (la API) debe cumplir.
abstract class DataSource {
  // --- Métodos de Usuario ---
  Future<Usuario?> login(String email, String password);
  Future<bool> register(String name, String email, String password, String phone);

  // --- Métodos del Cliente ---
  // CORREGIDO: getProductos ahora usa parámetros nombrados
  Future<List<Producto>> getProductos({String? query, String? categoria});

  Future<List<Ubicacion>> getUbicaciones(int idUsuario);
  Future<List<ProductoRankeado>> getRecomendaciones();
  Future<bool> addRecomendacion({ // <-- AÑADIDO
    required int idProducto,
    required int idUsuario,
    required int puntuacion,
    String? comentario,
  });
  Future<bool> placeOrder({ required Usuario user, required CartModel cart, required Ubicacion location });
  Future<List<Pedido>> getPedidos(int idUsuario);
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido);

  // --- Métodos de Administración ---
  Future<List<Pedido>> getPedidosPorEstado(String estado);
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado);
  Future<List<Producto>> getAllProductosAdmin();
  Future<Producto?> createProducto(Producto producto);
  Future<bool> updateProducto(Producto producto);
  Future<bool> deleteProducto(int idProducto);
  Future<Map<String, dynamic>> getAdminStats();

  // --- MÉTODOS DE DELIVERY AÑADIDOS ---
  Future<List<Pedido>> getPedidosDisponibles();
  Future<bool> asignarPedido(int idPedido, int idDelivery);
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery);

  // --- MÉTODOS DE TRACKING (AÑADIDOS) ---
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon);
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido);




}

