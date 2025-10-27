import '../models/cart_model.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../models/producto.dart';
import '../models/recomendacion_data.dart';
import '../models/ubicacion.dart';
import '../models/usuario.dart';

/// Define el contrato que cualquier fuente de datos (API, base de datos local, etc.) debe cumplir.
abstract class DataSource {
  void setAuthToken(String? token);

  // --- Métodos de Usuario ---
  Future<Usuario?> login(String email, String password);
  Future<bool> register(String name, String email, String password, String phone);
  Future<Usuario?> updateUsuario(Usuario usuario);

  // --- Métodos del Cliente ---
  Future<List<Producto>> getProductos({String? query, String? categoria});
  Future<Producto?> getProductoById(int id); // MÉTODO AÑADIDO
  Future<List<Ubicacion>> getUbicaciones(int idUsuario);
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

  // --- Métodos de Delivery ---
  Future<List<Pedido>> getPedidosDisponibles();
  Future<bool> asignarPedido(int idPedido, int idDelivery);
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery);
  Future<Map<String, dynamic>> getDeliveryStats(int idDelivery);

  // --- Métodos de Tracking ---
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon);
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido);

  // --- Módulo de Chat ---
  Future<int?> iniciarConversacion({
    required int idCliente,
    int? idDelivery,
    int? idAdminSoporte,
    int? idPedido,
  });
  Future<List<ChatConversation>> getConversaciones(int idUsuario);
  Future<List<ChatMessage>> getMensajesDeConversacion(int idConversacion);
  Future<bool> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String mensaje,
  });
}
