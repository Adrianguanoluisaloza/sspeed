import '../models/cart_model.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../models/ubicacion.dart';
import '../models/recomendacion_data.dart';
import 'api_data_source.dart';
import 'data_source.dart';

class DatabaseService implements DataSource {
  final DataSource _dataSource;
  DatabaseService() : _dataSource = ApiDataSource();

  @override
  void setAuthToken(String? token) => _dataSource.setAuthToken(token);

  // --- Métodos de Usuario ---
  @override
  Future<Usuario?> login(String email, String password) => _dataSource.login(email, password);

  @override
  Future<bool> register(String name, String email, String password, String phone) =>
      _dataSource.register(name, email, password, phone);

  @override
  Future<Usuario?> updateUsuario(Usuario usuario) => _dataSource.updateUsuario(usuario);

  // --- Métodos del Cliente ---
  @override
  Future<List<Producto>> getProductos({String? query, String? categoria}) =>
      _dataSource.getProductos(query: query, categoria: categoria);

  // CORRECCIÓN: Se implementa el método faltante
  @override
  Future<Producto?> getProductoById(int id) => _dataSource.getProductoById(id);

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) => _dataSource.getUbicaciones(idUsuario);

  @override
  Future<void> guardarUbicacion(Ubicacion ubicacion) => _dataSource.guardarUbicacion(ubicacion);

  @override
  Future<List<ProductoRankeado>> getRecomendaciones() => _dataSource.getRecomendaciones();

  @override
  Future<RecomendacionesProducto> getRecomendacionesPorProducto(int idProducto) =>
      _dataSource.getRecomendacionesPorProducto(idProducto);

  @override
  Future<bool> addRecomendacion({
    required int idProducto,
    required int idUsuario,
    required int puntuacion,
    String? comentario,
  }) =>
      _dataSource.addRecomendacion(
        idProducto: idProducto,
        idUsuario: idUsuario,
        puntuacion: puntuacion,
        comentario: comentario,
      );

  @override
  Future<bool> placeOrder({
    required Usuario user,
    required CartModel cart,
    required Ubicacion location,
    required String paymentMethod,
  }) =>
      _dataSource.placeOrder(
        user: user, 
        cart: cart, 
        location: location, 
        paymentMethod: paymentMethod,
      );

  @override
  Future<List<Pedido>> getPedidos(int idUsuario) => _dataSource.getPedidos(idUsuario);

  @override
  Future<PedidoDetalle?> getPedidoDetalle(int idPedido) =>
      _dataSource.getPedidoDetalle(idPedido);

  // --- Métodos de Administración ---
  @override
  Future<List<Pedido>> getPedidosPorEstado(String estado) =>
      _dataSource.getPedidosPorEstado(estado);

  @override
  Future<bool> updatePedidoEstado(int idPedido, String nuevoEstado) =>
      _dataSource.updatePedidoEstado(idPedido, nuevoEstado);

  @override
  Future<List<Producto>> getAllProductosAdmin() => _dataSource.getAllProductosAdmin();

  @override
  Future<Producto?> createProducto(Producto producto) =>
      _dataSource.createProducto(producto);

  @override
  Future<bool> updateProducto(Producto producto) =>
      _dataSource.updateProducto(producto);

  @override
  Future<bool> deleteProducto(int idProducto) => _dataSource.deleteProducto(idProducto);

  @override
  Future<Map<String, dynamic>> getAdminStats() => _dataSource.getAdminStats();

  // --- Métodos de Delivery ---
  @override
  Future<List<Pedido>> getPedidosDisponibles() =>
      _dataSource.getPedidosDisponibles();

  @override
  Future<bool> asignarPedido(int idPedido, int idDelivery) =>
      _dataSource.asignarPedido(idPedido, idDelivery);

  @override
  Future<List<Pedido>> getPedidosPorDelivery(int idDelivery) =>
      _dataSource.getPedidosPorDelivery(idDelivery);

  @override
  Future<Map<String, dynamic>> getDeliveryStats(int idDelivery) =>
      _dataSource.getDeliveryStats(idDelivery);

  // --- Métodos de Tracking ---
  @override
  Future<bool> updateRepartidorLocation(int idRepartidor, double lat, double lon) =>
      _dataSource.updateRepartidorLocation(idRepartidor, lat, lon);

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) =>
      _dataSource.getRepartidorLocation(idPedido);
      
  // --- Módulo de Chat ---
  @override
  Future<int?> iniciarConversacion({
    required int idCliente,
    int? idDelivery,
    int? idAdminSoporte,
    int? idPedido,
  }) =>
      _dataSource.iniciarConversacion(
        idCliente: idCliente,
        idDelivery: idDelivery,
        idAdminSoporte: idAdminSoporte,
        idPedido: idPedido,
      );

  @override
  Future<List<ChatConversation>> getConversaciones(int idUsuario) =>
      _dataSource.getConversaciones(idUsuario);

  @override
  Future<List<ChatMessage>> getMensajesDeConversacion(int idConversacion) =>
      _dataSource.getMensajesDeConversacion(idConversacion);

  @override
  Future<bool> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String mensaje,
  }) =>
      _dataSource.enviarMensaje(
        idConversacion: idConversacion,
        idRemitente: idRemitente,
        mensaje: mensaje,
      );
}
