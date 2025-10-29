package com.mycompany.delivery.api;

import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;
import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.controller.*;
import com.mycompany.delivery.api.model.*;
import com.mycompany.delivery.api.payloads.Payloads;
import com.mycompany.delivery.api.payloads.Payloads.PedidoPayload;
import com.mycompany.delivery.api.repository.ChatRepository;
import com.mycompany.delivery.api.repository.DashboardDAO;
import com.mycompany.delivery.api.util.ApiException;

// Usa tus Payloads externos (sin clases duplicadas)
import static com.mycompany.delivery.api.payloads.Payloads.*;

import java.sql.SQLException;
import java.util.*;
import com.mycompany.delivery.api.services.GeminiService; // Importar el nuevo servicio
import com.mycompany.delivery.api.util.ApiResponse;

import static com.mycompany.delivery.api.util.UbicacionValidator.*;
import static com.mycompany.delivery.api.util.UbicacionValidator.*;
import static spark.Spark.*;

/**
 * /**API principal unificada. API principal unificada.
 */

public class DeliveryApi {
    private static final Gson GSON = new Gson();
    private static final UsuarioController USUARIO_CONTROLLER = new UsuarioController();
    private static final ProductoController PRODUCTO_CONTROLLER = new ProductoController();
    private static final PedidoController PEDIDO_CONTROLLER = new PedidoController();
    private static final UbicacionController UBICACION_CONTROLLER = new UbicacionController();
    private static final RecomendacionController RECOMENDACION_CONTROLLER = new RecomendacionController();
    private static final DashboardDAO DASHBOARD_DAO = new DashboardDAO();
    private static final ChatRepository CHAT_REPOSITORY = new ChatRepository();
    private static final GeminiService GEMINI_SERVICE = new GeminiService();

    public static void main(String[] args) {
        // Cargar variables de entorno desde .env (dotenv-java)
        try {
            io.github.cdimascio.dotenv.Dotenv.configure().directory("../delivery-api") // Ajusta el path si tu .env está
                                                                                       // en otro lugar
                    .ignoreIfMalformed().ignoreIfMissing().load();
        } catch (io.github.cdimascio.dotenv.DotenvException | IllegalArgumentException e) {
            System.err.println("[WARN] No se pudo cargar .env: " + e.getMessage());
        }
        Database.ping();
        enableCORS();
        before("/pedidos/disponibles", (request, response) -> {
            String authHeader = request.headers("Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                halt(401, GSON.toJson(ApiResponse.error(401, "Token de autenticación requerido")));
            }
            String token = authHeader.substring(7);
            Usuario usuario = USUARIO_CONTROLLER.validarToken(token);
            if (usuario == null) {
                halt(401, GSON.toJson(ApiResponse.error(401, "Token inválido")));
            }
            if (!"repartidor".equalsIgnoreCase(usuario.getRol())) {
                halt(403, GSON.toJson(ApiResponse.error(403, "Acceso solo para repartidores")));
            }
            request.attribute("id_usuario", usuario.getIdUsuario());
        });
        setupRoutes();
        setupExceptionHandlers();
        System.out.println("[INFO] Servidor Delivery API iniciado en http://localhost:4567");
    }

    // --- RUTAS PRINCIPALES ---
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
        post("/geocodificar", (req, res) -> {
            Map<String, Object> body = parseBody(req, Map.class);
            String direccion = body != null ? (String) body.get("direccion") : null;
            return respond(res, UBICACION_CONTROLLER.geocodificarDireccion(direccion));
        }, obj -> GSON.toJson(obj));
    }

    // --- DASHBOARD ---
    private static void registerDashboardRoutes() {
        get("/admin/stats", (req, res) -> {
            return respond(res,
                    ApiResponse.success(200, "Estadísticas admin", DASHBOARD_DAO.obtenerEstadisticasAdmin()));
        }, obj -> GSON.toJson(obj));
        get("/delivery/stats/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res,
                    ApiResponse.success(200, "Estadísticas delivery", DASHBOARD_DAO.obtenerEstadisticasDelivery(id)));
        }, obj -> GSON.toJson(obj));
    }

    // --- AUTH ---
    private static void registerAuthRoutes() {
        post("/login", (req, res) -> {
            var body = parseBody(req, LoginRequest.class);
            return respond(res, USUARIO_CONTROLLER.login(body.getCorreo(), body.getContrasena()));
        }, obj -> GSON.toJson(obj));
        post("/registro", (req, res) -> {
            var b = parseBody(req, Payloads.RegistroRequest.class);
            if (!"cliente".equalsIgnoreCase(b.rol) && !"repartidor".equalsIgnoreCase(b.rol)) {
                throw new ApiException(400,
                        "El rol especificado '" + b.rol + "' no es válido. Debe ser 'cliente' o 'repartidor'.");
            }
            var u = new Usuario();
            u.setNombre(b.nombre);
            u.setCorreo(b.correo);
            u.setContrasena(b.contrasena);
            u.setTelefono(b.telefono);
            u.setRol(b.rol);
            return respond(res, USUARIO_CONTROLLER.registrar(u));
        }, obj -> GSON.toJson(obj));
        put("/usuarios/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            var body = parseBody(req, Usuario.class);
            body.setIdUsuario(id);
            return respond(res, USUARIO_CONTROLLER.actualizarUsuario(body));
        }, obj -> GSON.toJson(obj));
        delete("/usuarios/:id", (req, res) -> {
            int id = parseId(req.params(":id"));
            return respond(res, USUARIO_CONTROLLER.eliminarUsuario(id));
        }, obj -> GSON.toJson(obj));
    }

    // --- PRODUCTOS ---
    private static void registerProductoRoutes() {
        get("/productos", (req, res) -> {
            var q = req.queryParams("query");
            var cat = req.queryParams("categoria");
            var resp = (q != null || cat != null) ? PRODUCTO_CONTROLLER.buscarProductos(q, cat)
                    : PRODUCTO_CONTROLLER.getAllProductos();
            return respond(res, resp);
        }, obj -> GSON.toJson(obj));
        get("/productos/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, PRODUCTO_CONTROLLER.obtenerProducto(id));
        }, obj -> GSON.toJson(obj));
        get("/admin/productos", (req, res) -> {
            return respond(res, PRODUCTO_CONTROLLER.getAllProductos());
        }, obj -> GSON.toJson(obj));
        post("/admin/productos", (req, res) -> {
            var producto = parseBody(req, Producto.class);
            return respond(res, PRODUCTO_CONTROLLER.createProducto(producto));
        }, obj -> GSON.toJson(obj));
        put("/admin/productos/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            var producto = parseBody(req, Producto.class);
            return respond(res, PRODUCTO_CONTROLLER.updateProducto(id, producto));
        }, obj -> GSON.toJson(obj));
        delete("/admin/productos/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, PRODUCTO_CONTROLLER.deleteProducto(id));
        }, obj -> GSON.toJson(obj));
    }

    // --- PEDIDOS ---
    private static void registerPedidoRoutes() {
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
            return respond(res, PEDIDO_CONTROLLER.crearPedido(pedido, detalles));
        }, obj -> GSON.toJson(obj));
        get("/pedidos", (req, res) -> {
            return respond(res, PEDIDO_CONTROLLER.getPedidos());
        }, obj -> GSON.toJson(obj));
        get("/pedidos/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, PEDIDO_CONTROLLER.obtenerPedidoConDetalle(id));
        }, obj -> GSON.toJson(obj));
        get("/pedidos/cliente/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, PEDIDO_CONTROLLER.getPedidosPorCliente(id));
        }, obj -> GSON.toJson(obj));
        get("/pedidos/estado/:estado", (req, res) -> {
            var estado = req.params(":estado");
            return respond(res, PEDIDO_CONTROLLER.getPedidosPorEstado(estado));
        }, obj -> GSON.toJson(obj));
        get("/pedidos/delivery/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, PEDIDO_CONTROLLER.listarPedidosPorDelivery(id));
        }, obj -> GSON.toJson(obj));
        put("/pedidos/:id/estado", (req, res) -> {
            var id = parseId(req.params(":id"));
            var body = parseBody(req, EstadoUpdateRequest.class);
            return respond(res, PEDIDO_CONTROLLER.updateEstadoPedido(id, body.estado));
        }, obj -> GSON.toJson(obj));
        put("/pedidos/:id/asignar", (req, res) -> {
            var id = parseId(req.params(":id"));
            var body = parseBody(req, AsignarPedidoRequest.class);
            if (body.idDelivery == null) {
                throw new ApiException(400, "Debe especificar el repartidor");
            }
            return respond(res, PEDIDO_CONTROLLER.asignarPedido(id, body.idDelivery));
        }, obj -> GSON.toJson(obj));
    }

    // --- UBICACIONES ---
    private static void registerUbicacionRoutes() {
        post("/ubicaciones", (req, res) -> {
            var b = parseBody(req, Payloads.UbicacionRequest.class);
            var u = toUbicacion(b);
            return respond(res, UBICACION_CONTROLLER.guardarUbicacion(u));
        }, obj -> GSON.toJson(obj));
        put("/ubicaciones/:idUbicacion", (req, res) -> {
            var id = parseId(req.params(":idUbicacion"));
            var b = parseBody(req, Payloads.UbicacionRequest.class);
            UBICACION_CONTROLLER.actualizarCoordenadas(id, b.getLatitud(), b.getLongitud());
            return respond(res, ApiResponse.success("Ubicación actualizada correctamente"));
        }, obj -> GSON.toJson(obj));
        get("/ubicaciones/activas", (req, res) -> {
            return respond(res, UBICACION_CONTROLLER.listarActivas());
        }, obj -> GSON.toJson(obj));
        get("/ubicaciones/usuario/:id", (req, res) -> {
            var id = parseId(req.params(":id"));
            return respond(res, UBICACION_CONTROLLER.listarPorUsuario(id));
        }, obj -> GSON.toJson(obj));
    }

    // --- MENSAJES ---
    private static void registerMensajeRoutes() {
        post("/chat", (req, res) -> {
            var body = parseBody(req, Mensaje.class);
            return respond(res, CHAT_REPOSITORY.guardarMensaje(body));
        }, obj -> GSON.toJson(obj));
        get("/chat/:idPedido", (req, res) -> {
            var idPedido = parseId(req.params(":idPedido"));
            return respond(res, CHAT_REPOSITORY.obtenerChatPorPedido(idPedido));
        }, obj -> GSON.toJson(obj));
    }

    // --- RECOMENDACIONES ---
    private static void registerRecomendacionRoutes() {
        post("/recomendaciones", (req, res) -> {
            var body = parseBody(req, Recomendacion.class);
            return respond(res, RECOMENDACION_CONTROLLER.crearRecomendacion(body));
        }, obj -> GSON.toJson(obj));
        get("/recomendaciones/usuario/:id", (req, res) -> {
            var idUsuario = parseId(req.params(":id"));
            return respond(res, RECOMENDACION_CONTROLLER.obtenerRecomendacionesPorUsuario(idUsuario));
        }, obj -> GSON.toJson(obj));
    }

    // --- HELPERS Y UTILIDADES ---
    private static Ubicacion toUbicacion(Payloads.UbicacionRequest r) {
        if (r == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        requireValidCoordinates(r.getLatitud(), r.getLongitud(), "Coordenadas inválidas");
        Ubicacion u = new Ubicacion();
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
            System.err.println("[ERROR] Ocurrió un error inesperado: " + ex.getMessage());
            res.body(GSON.toJson(ApiResponse.error(500, "Ocurrió un error inesperado")));
        });
        notFound((req, res) -> {
            res.type("application/json");
            return GSON.toJson(ApiResponse.error(404, "Ruta no encontrada"));
        });
    }
}