import '../models/cart_model.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/pedido.dart';
import '../models/pedido_detalle.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../models/ubicacion.dart';
import '../models/recomendacion_data.dart';
import '../models/tracking_point.dart';
import 'api_data_source.dart';
import 'data_source.dart';

class DatabaseService implements DataSource {
  @override
  Future<bool> deleteUbicacion(int id) => _dataSource.deleteUbicacion(id);
  final DataSource _dataSource;
  DatabaseService() : _dataSource = ApiDataSource();

  @override
  void setAuthToken(String? token) => _dataSource.setAuthToken(token);

  // --- Métodos de Usuario ---
  @override
  Future<Usuario?> login(String email, String password) =>
      _dataSource.login(email, password);

  @override
  Future<bool> register(String name, String email, String password,
          String phone, String rol) =>
      _dataSource.register(name, email, password, phone, rol);

  @override
  Future<Usuario?> updateUsuario(Usuario usuario) =>
      _dataSource.updateUsuario(usuario);

  // --- Métodos de Usuario (añadido) ---
  @override
  Future<Usuario?> getUsuarioById(int idUsuario) =>
      _dataSource.getUsuarioById(idUsuario);

  // --- Métodos del Cliente ---
  @override
  Future<List<Producto>> getProductos({String? query, String? categoria}) =>
      _dataSource.getProductos(query: query, categoria: categoria);

  // CORRECCIÓN: Se implementa el método faltante
  @override
  Future<Producto?> getProductoById(int id) => _dataSource.getProductoById(id);

  @override
  Future<List<String>> getCategorias() => _dataSource.getCategorias();

  @override
  Future<List<Ubicacion>> getUbicaciones(int idUsuario) =>
      _dataSource.getUbicaciones(idUsuario);

  @override
  Future<void> guardarUbicacion(Ubicacion ubicacion) =>
      _dataSource.guardarUbicacion(ubicacion);

  @override
  Future<Map<String, dynamic>?> geocodificarDireccion(String direccion) =>
      _dataSource.geocodificarDireccion(direccion);

  @override
  Future<List<ProductoRankeado>> getRecomendaciones() =>
      _dataSource.getRecomendaciones();

  @override
  Future<RecomendacionesProducto> getRecomendacionesPorProducto(
          int idProducto) =>
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
  Future<List<Pedido>> getPedidos(int idUsuario) =>
      _dataSource.getPedidos(idUsuario);

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
  Future<List<Producto>> getAllProductosAdmin() =>
      _dataSource.getAllProductosAdmin();

  @override
  Future<Producto?> createProducto(Producto producto) =>
      _dataSource.createProducto(producto);

  @override
  Future<bool> updateProducto(Producto producto) =>
      _dataSource.updateProducto(producto);

  @override
  Future<bool> deleteProducto(int idProducto) =>
      _dataSource.deleteProducto(idProducto);

  @override
  Future<Map<String, dynamic>> getAdminStats() => _dataSource.getAdminStats();

  // --- Negocios ---
  @override
  Future<List<Usuario>> getNegocios() => _dataSource.getNegocios();

  @override
  Future<Usuario?> createNegocio(Usuario negocio) =>
      _dataSource.createNegocio(negocio);

  @override
  Future<Usuario?> getNegocioById(int id) => _dataSource.getNegocioById(id);

  @override
  Future<Usuario?> updateNegocio(Usuario negocio) =>
      _dataSource.updateNegocio(negocio);

  @override
  Future<List<Producto>> getProductosPorNegocio(int idNegocio) =>
      _dataSource.getProductosPorNegocio(idNegocio);

  @override
  Future<Producto?> createProductoParaNegocio(
          int idNegocio, Producto producto) =>
      _dataSource.createProductoParaNegocio(idNegocio, producto);

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
  Future<bool> updateRepartidorLocation(
          int idRepartidor, double lat, double lon) =>
      _dataSource.updateRepartidorLocation(idRepartidor, lat, lon);

  @override
  Future<Map<String, dynamic>?> getRepartidorLocation(int idPedido) =>
      _dataSource.getRepartidorLocation(idPedido);

  @override
  Future<List<Map<String, dynamic>>> getRepartidoresLocation(List<int> ids) =>
      _dataSource.getRepartidoresLocation(ids);

  @override
  Future<List<TrackingPoint>> getTrackingRoute(int idPedido) =>
      _dataSource.getTrackingRoute(idPedido);

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
  Future<Map<String, dynamic>> enviarMensaje({
    required int idConversacion,
    required int idRemitente,
    required String mensaje,
    bool esBot = false,
  }) =>
      _dataSource.enviarMensaje(
        idConversacion: idConversacion,
        idRemitente: idRemitente,
        mensaje: mensaje,
        esBot: esBot,
      );
}
