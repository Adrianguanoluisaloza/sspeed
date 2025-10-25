import '../models/cart_model.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../models/producto.dart';
import '../models/ubicacion.dart';
import '../models/usuario.dart';

/// Define el contrato que cualquier fuente de datos (API, base de datos local, etc.) debe cumplir.
///
/// Esto permite intercambiar la fuente de datos (por ejemplo, de una API a
/// una base de datos local para pruebas) sin tener que cambiar el resto de la app.
abstract class DataSource {
  Future<Usuario?> login(String email, String password);
  Future<bool> register(String nombre, String email, String password, String telefono);
  Future<List<Producto>> getProductos({String? query, String? categoria});
  Future<List<Ubicacion>> getUbicaciones(int idUsuario);
  Future<List<ProductoRankeado>> getRecomendaciones();
  Future<bool> addRecomendacion({
    required int idProducto,
    required int idUsuario,
    required int puntuacion,
    String? comentario,
  });
  Future<bool> placeOrder({
    required Usuario user,
    required CartModel cart,
    required Ubicacion location,
  });
  Future<List<Pedido>> getPedidos(int idUsuario);
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido);
  Future<List<Pedido>> getPedidosPorEstado(String estado);
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado);
  Future<List<Producto>> getAllProductosAdmin();
  Future<Producto?> createProducto(Producto producto);
  Future<bool> updateProducto(Producto producto);
  Future<bool> deleteProducto(int idProducto);
  Future<Map<String, dynamic>> getAdminStats();
  Future<List<Pedido>> getPedidosDisponibles();
  Future<bool> asignarPedido(int idPedido, int idDelivery);
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery);

  // --- NUEVO MÉTODO PARA ESTADÍSTICAS DEL DELIVERY ---
  Future<Map<String, dynamic>> getDeliveryStats(int idDelivery);

  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon);
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido);
}
