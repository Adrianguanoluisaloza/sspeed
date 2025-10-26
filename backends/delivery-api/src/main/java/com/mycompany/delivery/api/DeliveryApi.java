package com.mycompany.delivery.api;

import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;
import com.google.gson.annotations.SerializedName;
import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.controller.MensajeController;
import com.mycompany.delivery.api.controller.PedidoController;
import com.mycompany.delivery.api.controller.ProductoController;
import com.mycompany.delivery.api.controller.RecomendacionController;
import com.mycompany.delivery.api.controller.UbicacionController;
import com.mycompany.delivery.api.controller.UsuarioController;
import com.mycompany.delivery.api.model.DetallePedido;
import com.mycompany.delivery.api.model.Mensaje;
import com.mycompany.delivery.api.model.Pedido;
import com.mycompany.delivery.api.model.Producto;
import com.mycompany.delivery.api.model.RecomendacionRequest;
import com.mycompany.delivery.api.model.Ubicacion;
import com.mycompany.delivery.api.model.Usuario;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import spark.Request;
import spark.Response;

import static com.mycompany.delivery.api.util.UbicacionValidator.normalizeDescripcion;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireNonBlank;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireValidCoordinates;
import static spark.Spark.*;

/**
 * Punto de entrada de la API REST utilizada por el cliente Flutter.
 * <p>
 * Se reorganizó la definición de rutas después del merge fallido para mantener
 * una estructura limpia y fácilmente extensible sin sacrificar compatibilidad
 * con los controladores existentes.
 * </p>
 */
public final class DeliveryApi {

    private static final Gson GSON = new Gson();

    private static final UsuarioController USUARIO_CONTROLLER = new UsuarioController();
    private static final ProductoController PRODUCTO_CONTROLLER = new ProductoController();
    private static final PedidoController PEDIDO_CONTROLLER = new PedidoController();
    private static final UbicacionController UBICACION_CONTROLLER = new UbicacionController();
    private static final MensajeController MENSAJE_CONTROLLER = new MensajeController();
    private static final RecomendacionController RECOMENDACION_CONTROLLER = new RecomendacionController();
    private static final DashboardDAO DASHBOARD_DAO = new DashboardDAO();
    private static final UbicacionDAO UBICACION_DAO = new UbicacionDAO();

    private DeliveryApi() {
    }

    /**
     * Representa el cuerpo esperado para /login.
     * Esta versión es más flexible para admitir claves JSON alternativas (ej. email/correo).
     */
    static final class LoginRequest {
        @SerializedName("correo")
        String correo;
        @SerializedName("email")
        String email;
        @SerializedName("contrasena")
        String contrasena;
        @SerializedName("password")
        String password;

        String getCorreo() {
            return correo != null ? correo : email;
        }

        String getContrasena() {
            return contrasena != null ? contrasena : password;
        }
    }

    /**
     * Representa el cuerpo esperado para /registro.
     */
    static final class RegistroRequest {
        String nombre;
        String correo;
        String contrasena;
        String telefono;
    }

    /**
     * Representa el cuerpo esperado para crear o actualizar productos.
     */
    static final class ProductoPayload {
        String nombre;
        String descripcion;
        Double precio;
        @SerializedName("imagen_url")
        String imagenUrl;
        String categoria;
        Boolean disponible;
    }

    /**
     * Representa el detalle de un producto dentro de un pedido.
     */
    static final class PedidoDetallePayload {
        @SerializedName("id_producto")
        int idProducto;
        int cantidad;
        double subtotal;
        @SerializedName("precio_unitario")
        double precioUnitario;
    }

    /**
     * Representa el cuerpo necesario para registrar un pedido.
     */
    static final class PedidoPayload {
        @SerializedName("id_cliente")
        int idCliente;
        @SerializedName("id_delivery")
        Integer idDelivery;
        @SerializedName("direccion_entrega")
        String direccionEntrega;
        @SerializedName("metodo_pago")
        String metodoPago;
        String estado;
        Double total;
        List<PedidoDetallePayload> productos;
    }

    /**
     * Cuerpo utilizado para actualizar estados de pedido.
     */
    static final class EstadoUpdateRequest {
        String estado;
    }

    /**
     * Cuerpo utilizado para asignar un pedido a un repartidor.
     */
    static final class AsignarPedidoRequest {
        @SerializedName("id_delivery")
        Integer idDelivery;
    }

    /**
     * Cuerpo utilizado para enviar mensajes asociados a un pedido.
     */
    static final class MensajePayload {
        @SerializedName("id_remitente")
        Integer idRemitente;
        String mensaje;
    }

    /**
     * Cuerpo utilizado para actualizar el tracking de un repartidor.
     */
    static final class TrackingPayload {
        Double latitud;
        Double longitud;
    }

    public static void main(String[] args) {
        port(4567);
        Database.ping(); // Verificamos la conexión temprano para fallar rápido si la DB no responde.
        enableCORS();
        setupRoutes();
        setupExceptionHandlers();
        System.out.println("🚀 Servidor Delivery API iniciado en http://localhost:4567");
    }

    /**
     * Registra todas las rutas expuestas por la API agrupadas por dominio.
     */
    private static void setupRoutes() {
        registerAuthRoutes();
        registerUsuarioRoutes();
        registerProductoRoutes();
        registerRecomendacionRoutes();
        registerUbicacionRoutes();
        registerPedidoRoutes();
        registerAdminRoutes();
        registerDeliveryRoutes();
        registerTrackingRoutes();
        registerAliasRoutes();
        registerChatAliasRoutes();

        // Duplicamos todas las rutas bajo el prefijo /api para clientes que lo esperen
        path("/api", () -> {
            registerAuthRoutes();
            registerUsuarioRoutes();
            registerProductoRoutes();
            registerRecomendacionRoutes();
            registerUbicacionRoutes();
            registerPedidoRoutes();
            registerAdminRoutes();
            registerDeliveryRoutes();
            registerTrackingRoutes();
            registerAliasRoutes();
            registerChatAliasRoutes();
        });
    }

    private static void registerAuthRoutes() {
        post("/login", (req, res) -> {
            LoginRequest body = parseBody(req, LoginRequest.class);
            // Se usan los getters flexibles de LoginRequest
            ApiResponse<Usuario> response = USUARIO_CONTROLLER.login(body.getCorreo(), body.getContrasena());
            return respond(res, response);
        }, GSON::toJson);

        post("/registro", (req, res) -> {
            RegistroRequest body = parseBody(req, RegistroRequest.class);
            Usuario usuario = new Usuario();
            usuario.setNombre(body.nombre);
            usuario.setCorreo(body.correo);
            usuario.setContrasena(body.contrasena);
            usuario.setTelefono(body.telefono);
            ApiResponse<Void> response = USUARIO_CONTROLLER.registrar(usuario);
            return respond(res, response);
        }, GSON::toJson);
    }

    private static void registerUsuarioRoutes() {
        get("/usuarios", (req, res) -> respond(res, USUARIO_CONTROLLER.listarUsuarios()), GSON::toJson);
    }

    private static void registerProductoRoutes() {
        get("/productos", (req, res) -> {
            String termino = req.queryParams("q");
            String categoria = req.queryParams("categoria");
            ApiResponse<List<Producto>> response = PRODUCTO_CONTROLLER.buscarProductos(termino, categoria);
            return respond(res, response);
        }, GSON::toJson);
    }

    private static void registerRecomendacionRoutes() {
        get("/recomendaciones", (req, res) -> respond(res, obtenerRankingRecomendaciones()), GSON::toJson);

        post("/productos/:idProducto/recomendaciones", (req, res) -> {
            int idProducto = parseId(req.params(":idProducto"));
            RecomendacionRequest recomendacion = parseBody(req, RecomendacionRequest.class);

            if (recomendacion.getPuntuacion() < 1 || recomendacion.getPuntuacion() > 5) {
                throw new ApiException(400, "La puntuación debe estar entre 1 y 5");
            }

            boolean success = RECOMENDACION_CONTROLLER.guardarRecomendacion(
                    idProducto,
                    recomendacion.getIdUsuario(),
                    recomendacion.getPuntuacion(),
                    recomendacion.getComentario()
            );

            if (!success) {
                throw new ApiException(500, "No se pudo guardar la recomendación");
            }
            return respond(res, ApiResponse.success(201, "Recomendación registrada", null));
        }, GSON::toJson);
    }

    private static void registerUbicacionRoutes() {
        post("/ubicaciones", (req, res) -> {
            UbicacionRequest body = parseBody(req, UbicacionRequest.class);
            ApiResponse<Ubicacion> response = UBICACION_CONTROLLER.guardarUbicacion(toUbicacion(body, null));
            return respond(res, response);
        }, GSON::toJson);

        put("/ubicaciones/:idUbicacion", (req, res) -> {
            int idUbicacion = parseId(req.params(":idUbicacion"));
            UbicacionRequest body = parseBody(req, UbicacionRequest.class);
            ApiResponse<Ubicacion> response = UBICACION_CONTROLLER.guardarUbicacion(toUbicacion(body, idUbicacion));
            return respond(res, response);
        }, GSON::toJson);

        delete("/ubicaciones/:idUbicacion", (req, res) -> {
            int idUbicacion = parseId(req.params(":idUbicacion"));
            return respond(res, UBICACION_CONTROLLER.eliminarUbicacion(idUbicacion));
        }, GSON::toJson);

        get("/ubicaciones/usuario/:idUsuario", (req, res) -> {
            int idUsuario = parseId(req.params(":idUsuario"));
            return respond(res, UBICACION_CONTROLLER.getUbicacion(idUsuario));
        }, GSON::toJson);
    }

    private static void registerPedidoRoutes() {
        post("/pedidos", (req, res) -> {
            PedidoPayload payload = parseBody(req, PedidoPayload.class);
            List<DetallePedido> detalles = toDetalles(payload.productos);
            if (payload.total == null) {
                payload.total = calcularTotal(payload.productos);
            }
            Pedido pedido = toPedido(payload);
            ApiResponse<Pedido> response = PEDIDO_CONTROLLER.crearPedido(pedido, detalles);
            return respond(res, response);
        }, GSON::toJson);

        get("/pedidos", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidos()), GSON::toJson);
        get("/pedidos/:idPedido", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidoConDetalles(parseId(req.params(":idPedido")))), GSON::toJson);
        get("/pedidos/cliente/:idCliente", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidosPorCliente(parseId(req.params(":idCliente")))), GSON::toJson);
        get("/pedidos/estado/:estado", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidosPorEstado(req.params(":estado"))), GSON::toJson);

        put("/pedidos/:idPedido/estado", (req, res) -> {
            int idPedido = parseId(req.params(":idPedido"));
            EstadoUpdateRequest body = parseBody(req, EstadoUpdateRequest.class);
            ApiResponse<Void> response = PEDIDO_CONTROLLER.updateEstadoPedido(idPedido, body.estado);
            return respond(res, response);
        }, GSON::toJson);

        post("/pedidos/:idPedido/mensajes", (req, res) -> {
            int idPedido = parseId(req.params(":idPedido"));
            MensajePayload payload = parseBody(req, MensajePayload.class);
            Mensaje mensaje = new Mensaje();
            mensaje.setIdPedido(idPedido);
            mensaje.setIdRemitente(payload.idRemitente);
            mensaje.setMensaje(payload.mensaje);
            ApiResponse<Void> response = MENSAJE_CONTROLLER.enviarMensaje(mensaje);
            return respond(res, response);
        }, GSON::toJson);

        get("/pedidos/:idPedido/mensajes", (req, res) -> respond(res, MENSAJE_CONTROLLER.getMensajesPorPedido(parseId(req.params(":idPedido")))), GSON::toJson);
    }

    private static void registerAdminRoutes() {
        path("/admin", () -> {
            get("/productos", (req, res) -> respond(res, PRODUCTO_CONTROLLER.getAllProductos()), GSON::toJson);

            post("/productos", (req, res) -> {
                ProductoPayload payload = parseBody(req, ProductoPayload.class);
                ApiResponse<Producto> response = PRODUCTO_CONTROLLER.createProducto(toProducto(payload));
                return respond(res, response);
            }, GSON::toJson);

            put("/productos/:id", (req, res) -> {
                ProductoPayload payload = parseBody(req, ProductoPayload.class);
                ApiResponse<Producto> response = PRODUCTO_CONTROLLER.updateProducto(parseId(req.params(":id")), toProducto(payload));
                return respond(res, response);
            }, GSON::toJson);

            delete("/productos/:id", (req, res) -> respond(res, PRODUCTO_CONTROLLER.deleteProducto(parseId(req.params(":id")))), GSON::toJson);

            get("/stats", (req, res) -> respond(res, ApiResponse.success(200, "Estadísticas recuperadas", DASHBOARD_DAO.getStats())), GSON::toJson);
        });
    }

    private static void registerDeliveryRoutes() {
        path("/delivery", () -> {
            get("/pedidos/disponibles", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidosDisponibles()), GSON::toJson);
            get("/pedidos/:idDelivery", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidosPorDelivery(parseId(req.params(":idDelivery")))), GSON::toJson);
            get("/stats/:idDelivery", (req, res) -> respond(res, PEDIDO_CONTROLLER.getEstadisticasDelivery(parseId(req.params(":idDelivery")))), GSON::toJson);

            put("/pedidos/:idPedido/asignar", (req, res) -> {
                int idPedido = parseId(req.params(":idPedido"));
                AsignarPedidoRequest body = parseBody(req, AsignarPedidoRequest.class);
                if (body.idDelivery == null) {
                    throw new ApiException(400, "Debe especificar el repartidor");
                }
                ApiResponse<Void> response = PEDIDO_CONTROLLER.asignarPedido(idPedido, body.idDelivery);
                return respond(res, response);
            }, GSON::toJson);

            put("/:id/ubicacion", (req, res) -> {
                int idRepartidor = parseId(req.params(":id"));
                TrackingPayload body = parseBody(req, TrackingPayload.class);
                if (body.latitud == null || body.longitud == null) {
                    throw new ApiException(400, "Las coordenadas son obligatorias");
                }
                boolean actualizado = UBICACION_DAO.upsertLiveUbicacion(idRepartidor, body.latitud, body.longitud);
                if (!actualizado) {
                    throw new ApiException(500, "No se pudo actualizar la ubicación en vivo");
                }
                ApiResponse<Void> response = ApiResponse.success("Ubicación en vivo actualizada");
                return respond(res, response);
            }, GSON::toJson);
        });
    }

    // Alias planos para compatibilidad con el cliente Flutter
    private static void registerAliasRoutes() {
        get("/pedidos/disponibles", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidosDisponibles()), GSON::toJson);
        get("/pedidos/delivery/:idDelivery", (req, res) -> respond(res, PEDIDO_CONTROLLER.getPedidosPorDelivery(parseId(req.params(":idDelivery")))), GSON::toJson);
        put("/pedidos/:idPedido/asignar", (req, res) -> {
            int idPedido = parseId(req.params(":idPedido"));
            AsignarPedidoRequest body = parseBody(req, AsignarPedidoRequest.class);
            if (body.idDelivery == null) {
                throw new ApiException(400, "Debe especificar el repartidor");
            }
            ApiResponse<Void> response = PEDIDO_CONTROLLER.asignarPedido(idPedido, body.idDelivery);
            return respond(res, response);
        }, GSON::toJson);
    }

    // Endpoints de chat mínimos mapeados a mensajes por pedido
    private static void registerChatAliasRoutes() {
        post("/chat/mensajes", (req, res) -> {
            MensajePayload payload = parseBody(req, MensajePayload.class);
            if (payload.idRemitente == null || payload.mensaje == null || payload.mensaje.isBlank()) {
                throw new ApiException(400, "id_remitente y mensaje son obligatorios");
            }
            // id_conversacion se interpreta como id_pedido
            Map<String, Object> raw = GSON.fromJson(req.body(), Map.class);
            Object conv = raw.get("id_conversacion");
            if (conv == null) {
                throw new ApiException(400, "id_conversacion es obligatorio");
            }
            int idPedido;
            if (conv instanceof Number) {
                idPedido = ((Number) conv).intValue();
            } else {
                try { idPedido = Integer.parseInt(conv.toString()); } catch (NumberFormatException e) { throw new ApiException(400, "id_conversacion inválido"); }
            }
            Mensaje mensaje = new Mensaje();
            mensaje.setIdPedido(idPedido);
            mensaje.setIdRemitente(payload.idRemitente);
            mensaje.setMensaje(payload.mensaje);
            ApiResponse<Void> response = MENSAJE_CONTROLLER.enviarMensaje(mensaje);
            return respond(res, response);
        }, GSON::toJson);

        get("/chat/mensajes/:idConversacion", (req, res) -> {
            int idPedido = parseId(req.params(":idConversacion"));
            ApiResponse<List<Mensaje>> base = MENSAJE_CONTROLLER.getMensajesPorPedido(idPedido);
            List<Mensaje> lista = base.getData();
            List<Map<String, Object>> adaptada = new ArrayList<>();
            if (lista != null) {
                for (Mensaje m : lista) {
                    Map<String, Object> item = new HashMap<>();
                    item.put("id_mensaje", m.getIdMensaje());
                    item.put("id_conversacion", m.getIdPedido());
                    item.put("id_remitente", m.getIdRemitente());
                    item.put("mensaje", m.getMensaje());
                    item.put("fecha_envio", m.getFechaEnvio() != null ? m.getFechaEnvio().toInstant().toString() : null);
                    adaptada.add(item);
                }
            }
            return respond(res, ApiResponse.success(200, "Mensajes de conversacion", adaptada));
        }, GSON::toJson);

        get("/chat/conversaciones/:idUsuario", (req, res) -> {
            int idUsuario = parseId(req.params(":idUsuario"));
            ApiResponse<List<Pedido>> pedidosResp = PEDIDO_CONTROLLER.getPedidosPorCliente(idUsuario);
            List<Pedido> pedidos = pedidosResp.getData();
            List<Map<String, Object>> convs = new ArrayList<>();
            if (pedidos != null) {
                for (Pedido p : pedidos) {
                    Map<String, Object> c = new HashMap<>();
                    c.put("id_conversacion", p.getIdPedido());
                    c.put("id_pedido", p.getIdPedido());
                    c.put("id_cliente", idUsuario);
                    convs.add(c);
                }
            }
            return respond(res, ApiResponse.success(200, "Conversaciones", convs));
        }, GSON::toJson);
    }

    private static void registerTrackingRoutes() {
        get("/pedidos/:idPedido/tracking", (req, res) -> {
            int idPedido = parseId(req.params(":idPedido"));
            Map<String, Double> ubicacion = UBICACION_DAO.getLiveUbicacionByPedido(idPedido);
            if (ubicacion == null || ubicacion.isEmpty()) {
                throw new ApiException(404, "No hay tracking activo para el pedido");
            }
            return respond(res, ApiResponse.success(200, "Ubicación en vivo", ubicacion));
        }, GSON::toJson);
    }

    private static void setupExceptionHandlers() {
        exception(ApiException.class, (exception, req, res) -> {
            res.type("application/json");
            res.status(exception.getStatus());
            ApiResponse<Void> body = ApiResponse.error(exception.getStatus(), exception.getMessage(), exception.getDetails());
            res.body(GSON.toJson(body));
        });

        exception(JsonSyntaxException.class, (exception, req, res) -> {
            res.type("application/json");
            res.status(400);
            ApiResponse<Void> body = ApiResponse.error(400, "JSON mal formado", exception.getMessage());
            res.body(GSON.toJson(body));
        });

        exception(Exception.class, (exception, req, res) -> {
            res.type("application/json");
            res.status(500);
            exception.printStackTrace();
            ApiResponse<Void> body = ApiResponse.error(500, "Ocurrió un error inesperado", null);
            res.body(GSON.toJson(body));
        });

        notFound((req, res) -> {
            res.type("application/json");
            return GSON.toJson(ApiResponse.error(404, "Ruta no encontrada"));
        });
    }

    private static void enableCORS() {
        options("/*", (request, response) -> {
            String headers = request.headers("Access-Control-Request-Headers");
            if (headers != null) {
                response.header("Access-Control-Allow-Headers", headers);
            }

            String methods = request.headers("Access-Control-Request-Method");
            if (methods != null) {
                response.header("Access-Control-Allow-Methods", methods);
            }
            return "OK";
        });

        before((request, response) -> {
            response.header("Access-Control-Allow-Origin", "*");
            response.header("Content-Type", "application/json; charset=utf-8");
        });
    }

    private static <T> ApiResponse<T> respond(Response res, ApiResponse<T> response) {
        res.status(response.getStatus());
        return response;
    }

    private static int parseId(String raw) {
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Identificador inválido");
        }
    }

    private static <T> T parseBody(Request req, Class<T> clazz) {
        try {
            if (req.body() == null || req.body().isBlank()) {
                throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
            }
            T body = GSON.fromJson(req.body(), clazz);
            if (body == null) {
                throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
            }
            return body;
        } catch (JsonSyntaxException e) {
            throw e;
        }
    }

    private static Producto toProducto(ProductoPayload payload) {
        if (payload == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        Producto producto = new Producto();
        producto.setNombre(payload.nombre);
        producto.setDescripcion(payload.descripcion != null ? payload.descripcion : "");
        if (payload.precio == null) {
            throw new ApiException(400, "El precio es obligatorio");
        }
        producto.setPrecio(payload.precio);
        producto.setImagenUrl(payload.imagenUrl);
        producto.setCategoria(payload.categoria);
        producto.setDisponible(payload.disponible == null || payload.disponible);
        return producto;
    }

    private static Ubicacion toUbicacion(UbicacionRequest request, Integer idUbicacion) {
        if (request == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }

        Integer idUsuario = request.getIdUsuario();
        if (idUsuario == null || idUsuario <= 0) {
            throw new ApiException(400, "El idUsuario es obligatorio y debe ser mayor a cero");
        }

        Double latitud = request.getLatitud();
        Double longitud = request.getLongitud();
        try {
            // Validamos con el utilitario compartido para mantener mensajes coherentes y evitar coordenadas corruptas.
            requireValidCoordinates(latitud, longitud, "Las coordenadas proporcionadas son invalidas");
        } catch (IllegalArgumentException ex) {
            throw new ApiException(400, ex.getMessage());
        }

        String direccion;
        try {
            direccion = requireNonBlank(request.getDireccion(), "La direccion es obligatoria");
        } catch (IllegalArgumentException ex) {
            throw new ApiException(400, ex.getMessage());
        }

        String descripcion = normalizeDescripcion(request.getDescripcion());

        Ubicacion ubicacion = new Ubicacion();
        if (idUbicacion != null) {
            ubicacion.setIdUbicacion(idUbicacion);
        }
        ubicacion.setIdUsuario(idUsuario);
        ubicacion.setLatitud(latitud);
        ubicacion.setLongitud(longitud);
        ubicacion.setDescripcion(descripcion);
        ubicacion.setDireccion(direccion);
        ubicacion.setActiva(request.getActiva() == null || request.getActiva());
        return ubicacion;
    }

    private static Pedido toPedido(PedidoPayload payload) {
        if (payload == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        Pedido pedido = new Pedido();
        pedido.setIdCliente(payload.idCliente);
        if (payload.idDelivery != null) {
            pedido.setIdDelivery(payload.idDelivery);
        }
        pedido.setDireccionEntrega(payload.direccionEntrega);
        pedido.setMetodoPago(payload.metodoPago);
        pedido.setEstado(payload.estado != null ? payload.estado : "pendiente");
        if (payload.total == null) {
            throw new ApiException(400, "El total del pedido es obligatorio");
        }
        pedido.setTotal(payload.total);
        return pedido;
    }

    private static List<DetallePedido> toDetalles(List<PedidoDetallePayload> productos) {
        if (productos == null || productos.isEmpty()) {
            throw new ApiException(400, "Debe incluir productos en el pedido");
        }
        List<DetallePedido> detalles = new ArrayList<>();
        for (PedidoDetallePayload item : productos) {
            detalles.add(toDetallePedido(item));
        }
        return detalles;
    }

    private static DetallePedido toDetallePedido(PedidoDetallePayload item) {
        DetallePedido detalle = new DetallePedido();
        detalle.setIdProducto(item.idProducto);
        if (item.cantidad <= 0) {
            throw new ApiException(400, "La cantidad de cada producto debe ser mayor a cero");
        }
        detalle.setCantidad(item.cantidad);

        double subtotal = item.subtotal > 0 ? item.subtotal : item.precioUnitario * item.cantidad;
        double precioUnitario = item.precioUnitario > 0 ? item.precioUnitario : subtotal / item.cantidad;
        if (subtotal <= 0 || precioUnitario <= 0) {
            throw new ApiException(400, "Los importes del detalle deben ser mayores a cero");
        }
        detalle.setPrecioUnitario(precioUnitario); // Persistimos el precio unitario para el frontend Flutter.
        detalle.setSubtotal(subtotal);
        return detalle;
    }

    private static double calcularTotal(List<PedidoDetallePayload> productos) {
        return productos.stream()
                .mapToDouble(item -> {
                    if (item.cantidad <= 0) {
                        throw new ApiException(400, "La cantidad de cada producto debe ser mayor a cero");
                    }
                    double subtotal = item.subtotal > 0 ? item.subtotal : item.precioUnitario * item.cantidad;
                    double precioUnitario = item.precioUnitario > 0 ? item.precioUnitario : subtotal / item.cantidad;
                    if (subtotal <= 0 || precioUnitario <= 0) {
                        throw new ApiException(400, "Los importes del detalle deben ser mayores a cero");
                    }
                    return subtotal;
                })
                .sum();
    }

    private static ApiResponse<List<Map<String, Object>>> obtenerRankingRecomendaciones() {
        String sql = """
            SELECT
                p.id_producto,
                p.nombre,
                COALESCE(ROUND(AVG(r.puntuacion), 1), 0.0) AS rating_promedio,
                COUNT(r.id_recomendacion) AS total_reviews
            FROM productos p
            LEFT JOIN recomendaciones r ON p.id_producto = r.id_producto
            WHERE p.disponible = true
            GROUP BY p.id_producto, p.nombre
            ORDER BY rating_promedio DESC, total_reviews DESC
        """;

        List<Map<String, Object>> ranking = new ArrayList<>();
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                Map<String, Object> item = new HashMap<>();
                item.put("id_producto", rs.getInt("id_producto"));
                item.put("nombre", rs.getString("nombre"));
                item.put("rating_promedio", rs.getDouble("rating_promedio"));
                item.put("total_reviews", rs.getInt("total_reviews"));
                ranking.add(item);
            }
            return ApiResponse.success(200, "Ranking de productos", ranking);
        } catch (SQLException e) {
            System.err.println("❌ Error obteniendo ranking: " + e.getMessage());
            throw new ApiException(500, "No se pudo obtener el ranking de recomendaciones", e);
        }
    }
}
