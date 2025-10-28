package com.mycompany.delivery.api;

import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;
import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.controller.*;
import com.mycompany.delivery.api.model.*;
import com.mycompany.delivery.api.payloads.Payloads;
import com.mycompany.delivery.api.payloads.Payloads.PedidoPayload;
import com.mycompany.delivery.api.repository.ChatRepository;
import com.mycompany.delivery.api.util.ApiException;

// Usa tus Payloads externos (sin clases duplicadas)
import static com.mycompany.delivery.api.payloads.Payloads.*;

import java.sql.SQLException;
import java.util.*;
import com.mycompany.delivery.api.services.GeminiService; // Importar el nuevo servicio
import com.mycompany.delivery.api.util.ApiResponse;


import static com.mycompany.delivery.api.util.UbicacionValidator.*;
import static spark.Spark.*;

/**
 * API principal unificada.
 */
public final class DeliveryApi {
 
    private static 
final Gson GSON = new Gson();

    private static final UsuarioController USUARIO_CONTROLLER = new UsuarioController();
    private static final ProductoController PRODUCTO_CONTROLLER = new ProductoController();
    private static final PedidoController PEDIDO_CONTROLLER = new PedidoController();
    private static final UbicacionController UBICACION_CONTROLLER = new UbicacionController();
    private static final RecomendacionController RECOMENDACION_CONTROLLER = new RecomendacionController();

    private static final DashboardDAO DASHBOARD_DAO = new DashboardDAO();
    private static final ChatRepository CHAT_REPOSITORY = new ChatRepository();
    private static final GeminiService GEMINI_SERVICE = new GeminiService();

  

    private DeliveryApi() {
    }

    public static void main(String[] args) {
        port(4567);
        Database.ping();
        enableCORS();
            // Filtro de autenticación para pedidos/disponibles
            before("/pedidos/disponibles", (var request, var response) -> {
                String authHeader = request.headers("Authorization");
                if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                    halt(401, GSON.toJson(ApiResponse.error(401, "Token de autenticación requerido")));
                }
                String token = authHeader.substring(7);
                // Simulación de validación de token y obtención de usuario
                // Reemplaza esto por tu lógica real de validación JWT
                Usuario usuario = USUARIO_CONTROLLER.validarToken(token);
                if (usuario == null) {
                    halt(401, GSON.toJson(ApiResponse.error(401, "Token inválido")));
                }
                if (!"delivery".equalsIgnoreCase(usuario.getRol())) {
                     System.out.println("[DEBUG] usuario.getRol() = '" + usuario.getRol() + "'");
                      System.out.println("[DEBUG] ID de usuario: " + usuario.getIdUsuario());
    System.out.println("[DEBUG] Token recibido: " + token);
                    halt(403, GSON.toJson(ApiResponse.error(403, "Acceso solo para repartidores")));
                }
                request.attribute("id_usuario", usuario.getIdUsuario());
            });
        setupRoutes();
        setupExceptionHandlers();
        
       System.out.println("[INFO] Servidor Delivery API iniciado en http://localhost:4567");       
    }

    private static void setupRoutes() {
        registerAuthRoutes();
        registerProductoRoutes();
        registerPedidoRoutes(); // Contiene la ruta de pedidos disponibles
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
            return respond(res, ApiResponse.success(200, "Estadísticas admin", DASHBOARD_DAO.obtenerEstadisticasAdmin()));
        }, GSON::toJson);

        get("/delivery/stats/:id", (req, res)
                -> respond(res, ApiResponse.success(200, "Estadísticas delivery",
                        DASHBOARD_DAO.obtenerEstadisticasDelivery(parseId(req.params(":id"))))),
                GSON::toJson);
    }
    
// (Eliminado bloque duplicado de before("/pedidos/disponibles", ...) aquí)

// ===================== AUTH =====================
    private static void registerAuthRoutes() {
        post("/login", (req, res) -> {
            var body = parseBody(req, LoginRequest.class);
            return respond(res, USUARIO_CONTROLLER.login(body.getCorreo(), body.getContrasena()));
        }, GSON::toJson);

        post("/registro", (req, res) -> {
            var b = parseBody(req, Payloads.RegistroRequest.class);
            var u = new Usuario();
            u.setNombre(b.nombre);
            u.setCorreo(b.correo);
            u.setContrasena(b.contrasena);
            u.setTelefono(b.telefono);
            return respond(res, USUARIO_CONTROLLER.registrar(u));
        }, GSON::toJson);

    // ACTUALIZAR USUARIO EXISTENTE (nuevo endpoint)
   // ACTUALIZAR USUARIO EXISTENTE
put("/usuarios/:id", (req, res) -> {
    var id = parseId(req.params(":id"));
    var body = parseBody(req, Usuario.class);
    body.setIdUsuario(id);

    // Usa directamente el ApiResponse del controlador
    return respond(res, USUARIO_CONTROLLER.actualizarUsuario(body));
}, GSON::toJson);

// ELIMINAR USUARIO (nuevo endpoint)
delete("/usuarios/:id", (req, res) -> {
    int id = parseId(req.params(":id"));

    // Devuelve la respuesta ApiResponse del controlador
    return respond(res, USUARIO_CONTROLLER.eliminarUsuario(id));
}, GSON::toJson);
    
    }
    
    

// ===================== PRODUCTOS =====================
    private static void registerProductoRoutes() {
        get("/productos", (req, res) -> {
            var q = req.queryParams("query");
            var cat = req.queryParams("categoria");
            var resp = (q != null || cat != null)
                    ? PRODUCTO_CONTROLLER.buscarProductos(q, cat)
                    : PRODUCTO_CONTROLLER.getAllProductos();
            return respond(res, resp);
        }, GSON::toJson);
        get("/productos/:id", (req, res)
                -> respond(res, PRODUCTO_CONTROLLER.obtenerProducto(parseId(req.params(":id")))),
                GSON::toJson);
        get("/admin/productos", (req, res)
                -> respond(res, PRODUCTO_CONTROLLER.getAllProductos()),
                GSON::toJson);

        post("/admin/productos", (req, res) -> {
            var producto = parseBody(req, Producto.class);
            return respond(res, PRODUCTO_CONTROLLER.createProducto(producto));
        }, GSON::toJson);

        put("/admin/productos/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            var producto = parseBody(req, Producto.class);
            return respond(res, PRODUCTO_CONTROLLER.updateProducto(id, producto));
        }, GSON::toJson);

        delete("/admin/productos/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, PRODUCTO_CONTROLLER.deleteProducto(id));
        }, GSON::toJson);
    }

// ===================== PEDIDOS =====================
    // ===================== PEDIDOS =====================
private static void registerPedidoRoutes() {

    // Crear pedido
    post("/pedidos", (req, res) -> {
       var body = parseBody(req, PedidoPayload.class);

        if (body == null) {
            throw new ApiException(400, "El cuerpo de la solicitud está vacío o malformado");
        }

        var pedido = new Pedido();
        pedido.setIdCliente(body.idCliente);
        pedido.setIdDelivery(body.idDelivery);
     pedido.setIdUbicacion(body.getIdUbicacion());

        pedido.setMetodoPago(body.metodoPago);
        pedido.setEstado(body.estado != null ? body.estado : "pendiente");

        // Evita NullPointer si body.total viene nulo
        pedido.setTotal(body.total != null ? body.total : 0.0);

        var detalles = new ArrayList<DetallePedido>();
        if (body.productos != null && !body.productos.isEmpty()) {
            for (var it : body.productos) {
                var d = new DetallePedido();
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
    get("/pedidos", (req, res) -> {
        return respond(res, PEDIDO_CONTROLLER.getPedidos());
    }, GSON::toJson);

        get("/pedidos/:id", (req, res)
                -> respond(res, PEDIDO_CONTROLLER.obtenerPedidoConDetalle(parseId(req.params(":id")))),
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

    // Obtener estadâ”œÂ¡sticas del repartidor
    // get("/delivery/stats/:id", (req, res)
    //         -> respond(res, PEDIDO_CONTROLLER.obtenerEstadisticasDelivery(parseId(req.params(":id")))),
    //         GSON::toJson);

    // Actualizar estado del pedido
    put("/pedidos/:id/estado", (req, res) -> {
        var id = parseId(req.params(":id"));
        var body = parseBody(req, EstadoUpdateRequest.class);
        return respond(res, PEDIDO_CONTROLLER.updateEstadoPedido(id, body.estado));
    }, GSON::toJson);

    // Asignar pedido a un repartidor
    put("/pedidos/:id/asignar", (req, res) -> {
        int id = parseId(req.params(":id"));
        var body = parseBody(req, AsignarPedidoRequest.class);
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
        var b = parseBody(req, Payloads.UbicacionRequest.class);
        var u = toUbicacion(b);
        return respond(res, UBICACION_CONTROLLER.guardarUbicacion(u));
    }, GSON::toJson);

    put("/ubicaciones/:idUbicacion", (req, res) -> {
        var id = parseId(req.params(":idUbicacion"));
        var b = parseBody(req, Payloads.UbicacionRequest.class);
        UBICACION_CONTROLLER.actualizarCoordenadas(id, b.getLatitud(), b.getLongitud());
        return respond(res, ApiResponse.success("Ubicacionn actualizada correctamente"));
    }, GSON::toJson);

    // Reemplaza el GET /ubicaciones/usuario/:id por esta versionn
    get("/ubicaciones/usuario/:id", (req, res) ->
            respond(res, UBICACION_CONTROLLER.obtenerUbicacionesPorUsuario(parseId(req.params(":id"))))
    , GSON::toJson);

    get("/usuarios/:id/ubicaciones", (req, res) ->
            respond(res, UBICACION_CONTROLLER.obtenerUbicacionesPorUsuario(parseId(req.params(":id"))))
    , GSON::toJson);

    get("/ubicaciones/activas", (req, res)
            -> respond(res, UBICACION_CONTROLLER.listarActivas()),
            GSON::toJson);
}

// ===================== MENSAJES =====================
        private static void registerMensajeRoutes() {
        // ===================== CHAT (BOT Y NORMAL) =====================
        post("/chat/bot/mensajes", (req, res) -> {
            var body = parseBody(req, ChatMensajePayload.class);
            if (body == null || body.idRemitente == null || body.idRemitente <= 0 || body.mensaje == null || body.mensaje.isBlank()) {
                throw new ApiException(400, "idRemitente y mensaje son obligatorios");
            }
            long idConversacion = (body.idConversacion != null && body.idConversacion > 0)
                    ? body.idConversacion
                    : System.currentTimeMillis();
            var idCliente = (body.idCliente != null && body.idCliente > 0) ? body.idCliente : body.idRemitente;
            var mensaje = body.mensaje.trim();
            try {
                CHAT_REPOSITORY.ensureConversation(idConversacion, idCliente, body.idDelivery, null, body.idPedido);
                CHAT_REPOSITORY.insertMensaje(idConversacion, body.idRemitente, body.idDestinatario, mensaje);

                var botId = CHAT_REPOSITORY.ensureBotUser();
                var historial = CHAT_REPOSITORY.listarMensajes(idConversacion);

                // Llamada al nuevo servicio de Gemini
                var respuestaBot = GEMINI_SERVICE.generateReply(mensaje, historial, body.idRemitente);

                CHAT_REPOSITORY.insertMensaje(idConversacion, botId, body.idRemitente, respuestaBot);

                var data = new HashMap<String, Object>();
                data.put("id_conversacion", idConversacion);
                return respond(res, ApiResponse.success(201, "Conversacion actualizada", data));
            } catch (org.postgresql.util.PSQLException ex) {
                if ("42P01".equals(ex.getSQLState())) {
                    Map<String, Object> fallback = new HashMap<>();
                    fallback.put("id_conversacion", idConversacion);
                    fallback.put("mensajes", List.of());
                    return respond(res, ApiResponse.success(200, "Chat no configurado en la base de datos", fallback));
                }
                if ("23503".equals(ex.getSQLState())) {
                    throw new ApiException(404, "Referencia no válida para el mensaje de chat", ex);
                }
                throw new ApiException(500, "Error guardando mensaje de chat", ex);
            } catch (SQLException e) {
                throw new ApiException(500, "Error guardando mensaje de chat", e);
            }
        }, GSON::toJson);

        // Para mensajes normales (sin respuesta de bot)
        post("/chat/mensajes", (req, res) -> {
            var body = parseBody(req, ChatMensajePayload.class);
            if (body == null || body.idRemitente == null || body.idRemitente <= 0 || body.mensaje == null || body.mensaje.isBlank()) {
                throw new ApiException(400, "idRemitente y mensaje son obligatorios");
            }
            long idConversacion = (body.idConversacion != null && body.idConversacion > 0)
                    ? body.idConversacion
                    : System.currentTimeMillis();

            try {
                CHAT_REPOSITORY.ensureConversation(idConversacion, body.idCliente, body.idDelivery, null, body.idPedido);
                CHAT_REPOSITORY.insertMensaje(idConversacion, body.idRemitente, body.idDestinatario, body.mensaje.trim());

                var data = new HashMap<String, Object>();
                data.put("id_conversacion", idConversacion);
                return respond(res, ApiResponse.success(201, "Mensaje enviado", data));
            } catch (SQLException e) {
                throw new ApiException(500, "Error guardando mensaje de chat", e);
            }
        }, GSON::toJson);

        get("/chat/conversaciones/:id/mensajes", (req, res) -> {
            res.type("application/json");
            long idConversacion = parseLong(req.params(":id"));
            try {
                if (!CHAT_REPOSITORY.conversationExists(idConversacion)) { // TODO: check if this is correct
                    return respond(res, ApiResponse.success(200, "Mensajes recuperados", new ArrayList<>()));
                }
                List<Map<String, Object>> mensajes = CHAT_REPOSITORY.listarMensajes(idConversacion);
                return respond(res, ApiResponse.success(200, "Mensajes recuperados", mensajes));
            } catch (SQLException e) {
                throw new ApiException(500, "Error obteniendo mensajes de la conversación", e);
            }
        }, GSON::toJson);

        get("/chat/conversaciones/:id", (req, res) -> {
            res.type("application/json");
            int idUsuario = parseId(req.params(":id"));
            try {
                CHAT_REPOSITORY.ensureConversationForUser(idUsuario);
                List<Map<String, Object>> list = CHAT_REPOSITORY.listarConversacionesPorUsuario(idUsuario);
                return respond(res, ApiResponse.success(200, "Conversaciones obtenidas", list));
            } catch (SQLException e) {
                throw new ApiException(500, "Error obteniendo conversaciones", e);
            }
        }, GSON::toJson);
    }
// ===================== RECOMENDACIONES =====================
    private static void registerRecomendacionRoutes() {
        // Reemplaza el handler POST dentro de registerRecomendacionRoutes()
        post("/productos/:id/recomendaciones", (req, res) -> {
            int idProducto = parseId(req.params(":id"));
            var b = parseBody(req, RecomendacionPayload.class);
            var punt = (b == null) ? null : b.getPuntuacion();
            if (b == null || b.getIdUsuario() == null || b.getIdUsuario() <= 0 || punt == null || punt < 1 || punt > 5) {
                throw new ApiException(400, "id_usuario y puntuación/rating (1-5) son obligatorios");
            }
            return respond(res, RECOMENDACION_CONTROLLER.guardarRecomendacion(
                    idProducto, b.getIdUsuario(), punt, b.comentario));
        }, GSON::toJson);
    }

    private static void registerDeliveryRoutes() {
        path("/delivery", () -> {
            put("/:id/ubicacion", (req, res) -> {
                var idRepartidor = parseId(req.params(":id"));
                var b = parseBody(req, Payloads.TrackingPayload.class);
                boolean ok = UBICACION_CONTROLLER.actualizarUbicacionRepartidor(idRepartidor, b.latitud, b.longitud);
                if (!ok) {
                    throw new ApiException(500, "No se pudo actualizar la ubicación en vivo");
                }
                return respond(res, ApiResponse.success("Ubicación en vivo actualizada"));
            }, GSON::toJson);
        });
    }

    // ===================== TRACKING POR PEDIDO =====================
    private static void registerTrackingRoutes() {
        get("/pedidos/:idPedido/tracking", (req, res) -> {
            int idPedido = parseId(req.params(":idPedido"));
            return respond(res, UBICACION_CONTROLLER.obtenerUbicacionTracking(idPedido));
        }, GSON::toJson);
    }

    // ===================== HELPERS =====================
    private static Ubicacion toUbicacion(Payloads.UbicacionRequest r) {
        if (r == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        if (r.getIdUsuario() == null || r.getIdUsuario() <= 0) {
            throw new ApiException(400, "idUsuario es obligatorio");
        }
        requireValidCoordinates(r.getLatitud(), r.getLongitud(), "Coordenadas inválidas");
        var u = new Ubicacion();
        u.setIdUsuario(r.getIdUsuario());
        u.setLatitud(r.getLatitud());
        u.setLongitud(r.getLongitud());
        u.setDireccion(requireNonBlank(r.getDireccion(), "La dirección es obligatoria"));
        u.setDescripcion(normalizeDescripcion(r.getDescripcion()));
        u.setActiva(r.getActiva() == null || r.getActiva());
        return u;
    }

    private static int parseId(String raw) {
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Identificador inválido");
        }
    }

    private static long parseLong(String raw) {
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Identificador inválido");
        }
    }

    private static <T> T parseBody(spark.Request req, Class<T> clazz) {
        try {
            if (req.body() == null || req.body().isBlank()) {
                throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
            }
            var body = GSON.fromJson(req.body(), clazz);
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
            var headers = request.headers("Access-Control-Request-Headers");
            if (headers != null) {
                response.header("Access-Control-Allow-Headers", headers);
            }
            var methods = request.headers("Access-Control-Request-Method");
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
            res.body(GSON.toJson(ApiResponse.error(500, "Ocurrió un error inesperado")));
        });
        notFound((req, res) -> {
            res.type("application/json");
            return GSON.toJson(ApiResponse.error(404, "Ruta no encontrada"));
        });
    }}
