package com.mycompany.delivery.api;

import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;
import com.google.gson.annotations.SerializedName;
import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.controller.*;
import com.mycompany.delivery.api.model.*;
import com.mycompany.delivery.api.repository.UbicacionRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

// Ô£à Usa tus Payloads externos (sin clases duplicadas)
import static com.mycompany.delivery.api.payloads.Payloads.*;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.*;

import static com.mycompany.delivery.api.util.UbicacionValidator.*;
import static spark.Spark.*;

/**
 * API principal unificada y lista para compilar.
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
    private static final UbicacionRepository UBICACION_REPOSITORY = new UbicacionRepository();

  

    private DeliveryApi() {
    }

    // ====== Payloads locales (para evitar dependencias rotas) ======
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

    static final class RegistroRequest {

        String nombre;
        String correo;
        String contrasena;
        String telefono;
    }

    static final class UbicacionRequest {

        Integer idUsuario;
        Double latitud;
        Double longitud;
        String direccion;
        String descripcion;
        Boolean activa;

        public Integer getIdUsuario() {
            return idUsuario;
        }

        public Double getLatitud() {
            return latitud;
        }

        public Double getLongitud() {
            return longitud;
        }

        public String getDireccion() {
            return direccion;
        }

        public String getDescripcion() {
            return descripcion;
        }

        public Boolean getActiva() {
            return activa;
        }
    }

    static final class TrackingPayload {

        Double latitud;
        Double longitud;
    }

    static final class EstadoUpdateRequest {

        String estado;
    }

    static final class AsignarPedidoRequest {

        @SerializedName("id_delivery")
        Integer idDelivery;
    }

    static final class MensajePayload {

        @SerializedName("id_remitente")
        Integer idRemitente;
        String mensaje;
    }
    // Reemplaza tu clase interna RecomendacionPayload por esta

    static final class RecomendacionPayload {

        @SerializedName("id_usuario")
        Integer idUsuario;
        @SerializedName("puntuacion")
        Integer puntuacion;
        @SerializedName("rating")
        Integer rating;
        String comentario;

        Integer getPuntuacion() {
            return (puntuacion != null) ? puntuacion : rating;
        }
    }

    public static void main(String[] args) {
        port(4567);
        Database.ping();
        enableCORS();
        setupRoutes();
        setupExceptionHandlers();
        System.out.println("­ƒÜÇ Servidor Delivery API iniciado en http://localhost:4567");
    }

    private static void setupRoutes() {
        registerAuthRoutes();
        registerProductoRoutes();
        registerPedidoRoutes();
        registerUbicacionRoutes();
        registerMensajeRoutes();
        registerRecomendacionRoutes();
        registerDashboardRoutes();
        registerDeliveryRoutes();
        registerTrackingRoutes();

        // alias /api/*
        path("/api", DeliveryApi::setupRoutesWithoutApiWrapper);
    }

    // ===================== CONFIGURAR TODAS LAS RUTAS =====================
// ===================== CONFIGURAR TODAS LAS RUTAS =====================
    private static void setupRoutesWithoutApiWrapper() {
        registerAuthRoutes();
        registerProductoRoutes();
        registerPedidoRoutes();
        registerUbicacionRoutes();
        registerMensajeRoutes();
        registerRecomendacionRoutes();
        registerDashboardRoutes();
        registerDeliveryRoutes();
        registerTrackingRoutes();
    }

    private static void registerDashboardRoutes() {
        // ===================== DASHBOARD =====================
        get("/admin/stats", (req, res) -> {
            res.type("application/json");
            var out = new HashMap<String, Object>();
            try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement("SELECT * FROM fn_admin_dashboard()"); ResultSet rs = ps.executeQuery()) {

                if (rs.next()) {
                    out.put("ventas_hoy", rs.getBigDecimal("ventas_hoy"));
                    out.put("ventas_totales", rs.getBigDecimal("ventas_totales"));
                    out.put("pedidos_pendientes", rs.getInt("pedidos_pendientes"));
                    out.put("pedidos_entregados", rs.getInt("pedidos_entregados"));
                    out.put("nuevos_clientes", rs.getInt("nuevos_clientes"));
                    out.put("producto_mas_vendido", rs.getString("producto_mas_vendido"));
                    out.put("producto_mas_vendido_cantidad", rs.getInt("producto_mas_vendido_cantidad"));
                    return respond(res, ApiResponse.success(200, "Estad├¡sticas admin", out));
                }
            } catch (Exception ignore) {
                // caemos al fallback
            }
            // Fallback a prueba de todo
            out.put("ventas_hoy", java.math.BigDecimal.ZERO);
            out.put("ventas_totales", java.math.BigDecimal.ZERO);
            out.put("pedidos_pendientes", 0);
            out.put("pedidos_entregados", 0);
            out.put("nuevos_clientes", 0);
            out.put("producto_mas_vendido", "Sin datos");
            out.put("producto_mas_vendido_cantidad", 0);
            return respond(res, ApiResponse.success(200, "Estad├¡sticas admin (fallback)", out));
        }, GSON::toJson);

        get("/delivery/stats/:id", (req, res)
                -> respond(res, ApiResponse.success(200, "Estad├¡sticas delivery",
                        DASHBOARD_DAO.obtenerEstadisticasDelivery(parseId(req.params(":id"))))),
                GSON::toJson);
    }
    
    

// ===================== AUTH =====================
    private static void registerAuthRoutes() {
        post("/login", (req, res) -> {
            LoginRequest body = parseBody(req, LoginRequest.class);
            return respond(res, USUARIO_CONTROLLER.login(body.getCorreo(), body.getContrasena()));
        }, GSON::toJson);

        post("/registro", (req, res) -> {
            RegistroRequest b = parseBody(req, RegistroRequest.class);
            Usuario u = new Usuario();
            u.setNombre(b.nombre);
            u.setCorreo(b.correo);
            u.setContrasena(b.contrasena);
            u.setTelefono(b.telefono);
            return respond(res, USUARIO_CONTROLLER.registrar(u));
        }, GSON::toJson);
    
    // ­ƒö╣ ACTUALIZAR USUARIO EXISTENTE (nuevo endpoint)
   // ­ƒö╣ ACTUALIZAR USUARIO EXISTENTE
put("/usuarios/:id", (req, res) -> {
    int id = parseId(req.params(":id"));
    Usuario body = parseBody(req, Usuario.class);
    body.setIdUsuario(id);

    // Ô£à Usa directamente el ApiResponse del controlador
    return respond(res, USUARIO_CONTROLLER.actualizarUsuario(body));
}, GSON::toJson);

// ­ƒö╣ ELIMINAR USUARIO (nuevo endpoint)
delete("/usuarios/:id", (req, res) -> {
    int id = parseId(req.params(":id"));

    // Ô£à Devuelve la respuesta ApiResponse del controlador
    return respond(res, USUARIO_CONTROLLER.eliminarUsuario(id));
}, GSON::toJson);
    
    }
    
    

// ===================== PRODUCTOS =====================
    private static void registerProductoRoutes() {
        get("/productos", (req, res) -> {
            String q = req.queryParams("query");
            String cat = req.queryParams("categoria");
            ApiResponse<?> resp = (q != null || cat != null)
                    ? PRODUCTO_CONTROLLER.buscarProductos(q, cat)
                    : PRODUCTO_CONTROLLER.getAllProductos();
            return respond(res, resp);
        }, GSON::toJson);
        get("/admin/productos", (req, res)
                -> respond(res, PRODUCTO_CONTROLLER.getAllProductos()),
                GSON::toJson);
    }

// ===================== PEDIDOS =====================
    // ===================== PEDIDOS =====================
private static void registerPedidoRoutes() {

    // Crear pedido
    post("/pedidos", (req, res) -> {
       PedidoPayload body = parseBody(req, PedidoPayload.class);

        if (body == null) {
            throw new ApiException(400, "El cuerpo de la solicitud est├í vac├¡o o malformado");
        }

        Pedido pedido = new Pedido();
        pedido.setIdCliente(body.idCliente);
        pedido.setIdDelivery(body.idDelivery);
     pedido.setIdUbicacion(body.getIdUbicacion());

        pedido.setMetodoPago(body.metodoPago);
        pedido.setEstado(body.estado != null ? body.estado : "pendiente");

        // Ô£à Evita NullPointer si body.total viene nulo
        pedido.setTotal(body.total != null ? body.total : 0.0);

        List<DetallePedido> detalles = new ArrayList<>();
        if (body.productos != null && !body.productos.isEmpty()) {
            for (PedidoDetallePayload it : body.productos) {
                DetallePedido d = new DetallePedido();
                d.setIdProducto(it.idProducto);
                d.setCantidad(it.cantidad);
                d.setPrecioUnitario(it.precioUnitario);
                d.setSubtotal(it.subtotal);
                detalles.add(d);
            }
        } else {
            throw new ApiException(400, "El pedido no contiene productos");
        }

        try {
            return respond(res, PEDIDO_CONTROLLER.crearPedido(pedido, detalles));
        } catch (Exception e) {
            e.printStackTrace();
            throw new ApiException(500, "Error al crear el pedido: " + e.getMessage());
        }

    }, GSON::toJson);

    // Listar todos los pedidos
    get("/pedidos", (req, res)
            -> respond(res, PEDIDO_CONTROLLER.getPedidos()),
            GSON::toJson);

    // Listar pedidos por cliente
    get("/pedidos/cliente/:id", (req, res)
            -> respond(res, PEDIDO_CONTROLLER.getPedidosPorCliente(parseId(req.params(":id")))),
            GSON::toJson);

    // Listar pedidos por estado
    get("/pedidos/estado/:estado", (req, res)
            -> respond(res, PEDIDO_CONTROLLER.getPedidosPorEstado(req.params(":estado"))),
            GSON::toJson);

    // Listar pedidos disponibles (para repartidores)
    get("/pedidos/disponibles", (req, res)
            -> respond(res, PEDIDO_CONTROLLER.listarPedidosDisponibles()),
            GSON::toJson);

    // Listar pedidos asignados a un repartidor
    get("/pedidos/delivery/:id", (req, res)
            -> respond(res, PEDIDO_CONTROLLER.listarPedidosPorDelivery(parseId(req.params(":id")))),
            GSON::toJson);

    // Obtener estad├¡sticas del repartidor
    get("/delivery/stats/:id", (req, res)
            -> respond(res, PEDIDO_CONTROLLER.obtenerEstadisticasDelivery(parseId(req.params(":id")))),
            GSON::toJson);

    // Actualizar estado del pedido
    put("/pedidos/:id/estado", (req, res) -> {
        int id = parseId(req.params(":id"));
        EstadoUpdateRequest body = parseBody(req, EstadoUpdateRequest.class);
        return respond(res, PEDIDO_CONTROLLER.updateEstadoPedido(id, body.estado));
    }, GSON::toJson);

    // Asignar pedido a un repartidor
    put("/pedidos/:id/asignar", (req, res) -> {
        int id = parseId(req.params(":id"));
        AsignarPedidoRequest body = parseBody(req, AsignarPedidoRequest.class);
        if (body.idDelivery == null) {
            throw new ApiException(400, "Debe especificar el repartidor");
        }
        return respond(res, PEDIDO_CONTROLLER.asignarPedido(id, body.idDelivery));
    }, GSON::toJson);
}

// ===================== UBICACIONES =====================
   // ===================== UBICACIONES =====================
private static void registerUbicacionRoutes() {
    post("/ubicaciones", (req, res) -> {
        UbicacionRequest b = parseBody(req, UbicacionRequest.class);
        Ubicacion u = toUbicacion(b);
        return respond(res, UBICACION_CONTROLLER.guardarUbicacion(u));
    }, GSON::toJson);

    put("/ubicaciones/:idUbicacion", (req, res) -> {
        int id = parseId(req.params(":idUbicacion"));
        UbicacionRequest b = parseBody(req, UbicacionRequest.class);
        UBICACION_CONTROLLER.actualizarCoordenadas(id, b.getLatitud(), b.getLongitud());
        return respond(res, ApiResponse.success("Ubicaci├│n actualizada correctamente"));
    }, GSON::toJson);

    // Reemplaza el GET /ubicaciones/usuario/:id por esta versi├│n
    get("/ubicaciones/usuario/:id", (req, res) -> {
        res.type("application/json");
        int id = parseId(req.params(":id"));
        String sql = "SELECT id_ubicacion,id_usuario,latitud,longitud,direccion,descripcion "
                + "FROM ubicaciones WHERE id_usuario = ? ORDER BY id_ubicacion DESC";
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                var list = new ArrayList<Map<String, Object>>();
                while (rs.next()) {
                    var m = new HashMap<String, Object>();
                    m.put("id_ubicacion", rs.getInt("id_ubicacion"));
                    m.put("id_usuario", rs.getInt("id_usuario"));
                    m.put("latitud", rs.getDouble("latitud"));
                    m.put("longitud", rs.getDouble("longitud"));
                    m.put("direccion", rs.getString("direccion"));
                    m.put("descripcion", rs.getString("descripcion"));
                    list.add(m);
                }
                return respond(res, ApiResponse.success(200, "ok", list));
            }
        } catch (Exception e) {
            res.status(500);
            return ApiResponse.error(500, "Error obteniendo ubicaciones");
        }
    }, GSON::toJson);

    get("/ubicaciones/activas", (req, res)
            -> respond(res, UBICACION_CONTROLLER.listarActivas()),
            GSON::toJson);
}

// ===================== MENSAJES =====================
    private static void registerMensajeRoutes() {
        // Crear mensaje
        post("/pedidos/:id/mensajes", (req, res) -> {
            int idPedido = parseId(req.params(":id"));
            MensajePayload b = parseBody(req, MensajePayload.class);
            if (b.idRemitente == null || b.mensaje == null || b.mensaje.isBlank()) {
                throw new ApiException(400, "id_remitente y mensaje son obligatorios");
            }
            Mensaje m = new Mensaje();
            m.setIdPedido(idPedido);
            m.setIdRemitente(b.idRemitente);
            m.setMensaje(b.mensaje);
            return respond(res, MENSAJE_CONTROLLER.enviarMensaje(m));
        }, GSON::toJson);

        // Listar mensajes
        get("/pedidos/:id/mensajes", (req, res)
                -> respond(res, MENSAJE_CONTROLLER.getMensajesPorPedido(parseId(req.params(":id")))),
                GSON::toJson);

        // A├▒ade dentro de registerMensajeRoutes() o crea registerChatRoutes() si prefieres
        get("/chat/conversaciones/:id", (req, res) -> {
            res.type("application/json");
            int id = parseId(req.params(":id"));
            String sql
                    = "SELECT id_conversacion,id_pedido,id_cliente,id_delivery,id_admin_soporte,fecha_creacion,activa "
                    + "FROM chat_conversaciones "
                    + "WHERE id_cliente = ? OR id_delivery = ? OR id_admin_soporte = ? "
                    + "ORDER BY id_conversacion DESC";
            try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
                ps.setInt(1, id);
                ps.setInt(2, id);
                ps.setInt(3, id);
                try (ResultSet rs = ps.executeQuery()) {
                    var list = new ArrayList<Map<String, Object>>();
                    while (rs.next()) {
                        var m = new HashMap<String, Object>();
                        m.put("id_conversacion", rs.getInt("id_conversacion"));
                        m.put("id_pedido", (Integer) rs.getObject("id_pedido"));
                        m.put("id_cliente", rs.getInt("id_cliente"));
                        m.put("id_delivery", (Integer) rs.getObject("id_delivery"));
                        // si la columna no existe/nula, caemos a null sin petar
                        Object adminSoporte = null;
                        try {
                            adminSoporte = rs.getObject("id_admin_soporte");
                        } catch (Exception ignore) {
                        }
                        m.put("id_admin_soporte", (Integer) adminSoporte);
                        m.put("fecha_creacion", rs.getTimestamp("fecha_creacion"));
                        Object activaObj = null;
                        try {
                            activaObj = rs.getObject("activa");
                        } catch (Exception ignore) {
                        }
                        m.put("activa", (Boolean) activaObj);
                        list.add(m);
                    }
                    return respond(res, ApiResponse.success(200, "ok", list));
                }
            } catch (org.postgresql.util.PSQLException ex) {
                if ("42P01".equals(ex.getSQLState())) { // relation does not exist
                    return respond(res, ApiResponse.success(200, "ok (sin tabla chat_conversaciones)", new ArrayList<>()));
                }
                throw new ApiException(500, "Error obteniendo conversaciones", ex);
            } catch (Exception e) {
                throw new ApiException(500, "Error obteniendo conversaciones", e);
            }
        }, GSON::toJson);

    }

// ===================== RECOMENDACIONES =====================
    private static void registerRecomendacionRoutes() {
        // Reemplaza el handler POST dentro de registerRecomendacionRoutes()
        post("/productos/:id/recomendaciones", (req, res) -> {
            int idProducto = parseId(req.params(":id"));
            RecomendacionPayload b = parseBody(req, RecomendacionPayload.class);
            Integer punt = (b == null) ? null : b.getPuntuacion();
            if (b == null || b.idUsuario == null || b.idUsuario <= 0 || punt == null || punt < 1 || punt > 5) {
                throw new ApiException(400, "id_usuario y puntuaci├│n/rating (1-5) son obligatorios");
            }
            return respond(res, RECOMENDACION_CONTROLLER.guardarRecomendacion(
                    idProducto, b.idUsuario, punt, b.comentario));
        }, GSON::toJson);

// ===================== RECOMENDACIONES =====================
        get("/recomendaciones", (req, res) -> {
            res.type("application/json");
            String sql
                    = "SELECT r.id_recomendacion, r.id_producto, r.id_usuario, r.comentario, r.puntuacion AS rating, "
                    + "       r.fecha AS fecha_creacion, p.nombre AS producto, u.nombre AS usuario "
                    + "FROM recomendaciones r "
                    + "JOIN productos p ON p.id_producto = r.id_producto "
                    + "JOIN usuarios  u ON u.id_usuario  = r.id_usuario "
                    + "ORDER BY r.puntuacion DESC, r.fecha DESC LIMIT 4";

            try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {

                List<Map<String, Object>> list = new ArrayList<>();
                while (rs.next()) {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id_recomendacion", rs.getInt("id_recomendacion"));
                    m.put("id_producto", rs.getInt("id_producto"));
                    m.put("id_usuario", rs.getInt("id_usuario"));
                    m.put("comentario", rs.getString("comentario"));
                    m.put("rating", rs.getInt("rating"));
                    m.put("fecha_creacion", rs.getTimestamp("fecha_creacion"));
                    m.put("producto", rs.getString("producto"));
                    m.put("usuario", rs.getString("usuario"));
                    list.add(m);
                }

                res.status(200);
                return list; // ­ƒæê AQU├ì EL CAMBIO

            } catch (org.postgresql.util.PSQLException ex) {
                if ("42P01".equals(ex.getSQLState())) {
                    res.status(200);
                    return new ArrayList<>();
                }
                throw new ApiException(500, "Error listando recomendaciones", ex);
            } catch (Exception e) {
                throw new ApiException(500, "Error listando recomendaciones", e);
            }
        }, GSON::toJson);

    }

// ===================== DELIVERY: LIVE TRACKING =====================
    private static void registerDeliveryRoutes() {
        path("/delivery", () -> {
            put("/:id/ubicacion", (req, res) -> {
                int idRepartidor = parseId(req.params(":id"));
                TrackingPayload b = parseBody(req, TrackingPayload.class);
                if (b.latitud == null || b.longitud == null) {
                    throw new ApiException(400, "Coordenadas obligatorias");
                }
                boolean ok = UBICACION_REPOSITORY.actualizarUbicacionLive(idRepartidor, b.latitud, b.longitud);
                if (!ok) {
                    throw new ApiException(500, "No se pudo actualizar la ubicaci├│n en vivo");
                }
                return respond(res, ApiResponse.success("Ubicaci├│n en vivo actualizada"));
            }, GSON::toJson);
        });
    }

    // ===================== TRACKING POR PEDIDO =====================
    private static void registerTrackingRoutes() {
        get("/pedidos/:idPedido/tracking", (req, res) -> {
            int idPedido = parseId(req.params(":idPedido"));
            Map<String, Double> ubicacion = new HashMap<>();
            try (Connection conn = Database.getConnection(); PreparedStatement st = conn.prepareStatement(
                    "SELECT u.latitud, u.longitud "
                    + "FROM ubicaciones u JOIN pedidos p ON p.id_delivery = u.id_usuario "
                    + "WHERE p.id_pedido = ? AND u.descripcion = 'LIVE_TRACKING' "
                    + "ORDER BY u.id_ubicacion DESC LIMIT 1")) {
                st.setInt(1, idPedido);
                try (ResultSet rs = st.executeQuery()) {
                    if (rs.next()) {
                        ubicacion.put("latitud", rs.getDouble("latitud"));
                        ubicacion.put("longitud", rs.getDouble("longitud"));
                    }
                }
            }
            if (ubicacion.isEmpty()) {
                throw new ApiException(404, "No hay tracking activo para el pedido");
            }
            return respond(res, ApiResponse.success(200, "Ubicaci├│n en vivo", ubicacion));
        }, GSON::toJson);
    }

    // ===================== HELPERS =====================
    private static Ubicacion toUbicacion(UbicacionRequest r) {
        if (r == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        if (r.getIdUsuario() == null || r.getIdUsuario() <= 0) {
            throw new ApiException(400, "idUsuario es obligatorio");
        }
        requireValidCoordinates(r.getLatitud(), r.getLongitud(), "Coordenadas inv├ílidas");
        Ubicacion u = new Ubicacion();
        u.setIdUsuario(r.getIdUsuario());
        u.setLatitud(r.getLatitud());
        u.setLongitud(r.getLongitud());
        u.setDireccion(requireNonBlank(r.getDireccion(), "La direcci├│n es obligatoria"));
        u.setDescripcion(normalizeDescripcion(r.getDescripcion()));
        u.setActiva(r.getActiva() == null || r.getActiva());
        return u;
    }

    private static int parseId(String raw) {
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Identificador inv├ílido");
        }
    }

    private static <T> T parseBody(spark.Request req, Class<T> clazz) {
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
            throw new ApiException(400, "JSON mal formado", e);
        }
    }

    private static <T> ApiResponse<T> respond(spark.Response res, ApiResponse<T> response) {
        res.status(response.getStatus());
        return response;
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

    private static void setupExceptionHandlers() {
        exception(ApiException.class, (ex, req, res) -> {
            res.type("application/json");
            res.status(ex.getStatus());
            res.body(GSON.toJson(ApiResponse.error(ex.getStatus(), ex.getMessage(), ex.getDetails())));
        });
        exception(Exception.class, (ex, req, res) -> {
            res.type("application/json");
            res.status(500);
            ex.printStackTrace();
            res.body(GSON.toJson(ApiResponse.error(500, "Ocurri├│ un error inesperado")));
        });
        notFound((req, res) -> {
            res.type("application/json");
            return GSON.toJson(ApiResponse.error(404, "Ruta no encontrada"));
        });
    }}