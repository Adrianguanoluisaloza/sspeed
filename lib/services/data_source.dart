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

/// Define el contrato que cualquier fuente de datos (API, base de datos local, etc.) debe cumplir.
abstract class DataSource {
  Future<bool> deleteUbicacion(int id);
  void setAuthToken(String? token);

  // --- Métodos de Usuario ---
  Future<Usuario?> login(String email, String password);
  Future<bool> register(
      String name, String email, String password, String phone, String rol);
  Future<Usuario?> updateUsuario(Usuario usuario);

  // --- Métodos del Cliente ---
  Future<List<Producto>> getProductos({String? query, String? categoria});
  Future<Producto?> getProductoById(int id); // MÉTODO AÑADIDO
  Future<List<Ubicacion>> getUbicaciones(int idUsuario);
  Future<void> guardarUbicacion(Ubicacion ubicacion);
  Future<Map<String, dynamic>?> geocodificarDireccion(String direccion);
  Future<List<ProductoRankeado>> getRecomendaciones();
  Future<RecomendacionesProducto> getRecomendacionesPorProducto(int idProducto);
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
    required String paymentMethod,
  });
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

  // --- Módulo de Negocios ---
  Future<List<Usuario>> getNegocios();
  Future<Usuario?> createNegocio(Usuario negocio);
  Future<Usuario?> getNegocioById(int id);
  Future<Usuario?> updateNegocio(Usuario negocio);
  Future<List<Producto>> getProductosPorNegocio(int idNegocio);
  Future<Producto?> createProductoParaNegocio(int idNegocio, Producto producto);

  // --- Métodos de Delivery ---
  Future<List<Pedido>> getPedidosDisponibles();
  Future<bool> asignarPedido(int idPedido, int idDelivery);
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery);
  Future<Map<String, dynamic>> getDeliveryStats(int idDelivery);

  // --- Métodos de Tracking ---
  Future<bool> updateRepartidorLocation(
      int idRepartidor, double lat, double lon);
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido);
  // CORRECCIÓN: Se añade la definición del método que faltaba.
  Future<List<Map<String, dynamic>>> getRepartidoresLocation(List<int> ids);
  Future<List<TrackingPoint>> getTrackingRoute(int idPedido);

  // --- Módulo de Chat ---
  Future<int?> iniciarConversacion({
    required int idCliente,
    int? idDelivery,
    int? idAdminSoporte,
    int? idPedido,
  });
  Future<List<ChatConversation>> getConversaciones(int idUsuario);
  Future<List<ChatMessage>> getMensajesDeConversacion(int idConversacion);
  Future<Map<String, dynamic>> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String mensaje,
    bool esBot = false,
  });
}
