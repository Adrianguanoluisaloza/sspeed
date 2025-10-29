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
import com.mycompany.delivery.api.services.GeminiService;
import com.mycompany.delivery.api.util.ApiResponse;

import io.javalin.Javalin;
import io.javalin.http.Context;
import io.javalin.json.JsonMapper;
import org.jetbrains.annotations.NotNull;

import java.lang.reflect.Type;
import java.util.*;

import static com.mycompany.delivery.api.payloads.Payloads.*;
import static com.mycompany.delivery.api.util.UbicacionValidator.*;

/**
 * API principal unificada, migrada a Javalin.
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
        // Cargar variables de entorno
        try {
            io.github.cdimascio.dotenv.Dotenv.configure().directory("../delivery-api").ignoreIfMalformed()
                    .ignoreIfMissing().load();
        } catch (io.github.cdimascio.dotenv.DotenvException | IllegalArgumentException e) {
            System.err.println("[WARN] No se pudo cargar .env: " + e.getMessage());
        }

        // Ping a la base de datos para asegurar conexión
        Database.ping();

        // Configurar el mapeador de JSON para usar Gson
        JsonMapper gsonMapper = new JsonMapper() {
            @NotNull
            @Override
            public <T> T fromJsonString(@NotNull String json, @NotNull Type targetType) {
                try {
                    if (json.isBlank()) {
                        throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
                    }
                    T body = GSON.fromJson(json, targetType);
                    if (body == null) {
                        throw new ApiException(400, "El cuerpo de la solicitud es obligatorio o el JSON es inválido");
                    }
                    return body;
                } catch (JsonSyntaxException e) {
                    throw new ApiException(400, "JSON mal formado", e);
                }
            }

            @NotNull
            @Override
            public String toJsonString(@NotNull Object obj, @NotNull Type type) {
                return GSON.toJson(obj, type);
            }
        };

        // Crear y configurar la aplicación Javalin
        Javalin app = Javalin.create(config -> {
            config.jsonMapper(gsonMapper);
            config.http.defaultContentType = "application/json; charset=utf-8";
        }).start(4567);

        // Middleware CORS manual para todas las rutas
        app.before(ctx -> {
            ctx.header("Access-Control-Allow-Origin", "*");
            ctx.header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS");
            ctx.header("Access-Control-Allow-Headers", "Authorization,Content-Type,Accept,Origin");
        });
        app.options("/*", ctx -> {
            ctx.status(200);
        });

        System.out.println("[INFO] Servidor Delivery API iniciado en http://localhost:4567");

        // --- MIDDLEWARE (FILTROS) ---
        app.before("/pedidos/disponibles", ctx -> {
            String authHeader = ctx.header("Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                ctx.status(401);
                ctx.result(GSON.toJson(ApiResponse.error(401, "Token de autenticación requerido")));
                return;
            }
            String token = authHeader.substring(7);
            Usuario usuario = USUARIO_CONTROLLER.validarToken(token);
            if (usuario == null) {
                ctx.status(401);
                ctx.result(GSON.toJson(ApiResponse.error(401, "Token inválido")));
                return;
            }
            if (!"repartidor".equalsIgnoreCase(usuario.getRol())) {
                ctx.status(403);
                ctx.result(GSON.toJson(ApiResponse.error(403, "Acceso solo para repartidores")));
                return;
            }
            ctx.attribute("id_usuario", usuario.getIdUsuario());
        });

        // --- MANEJO DE EXCEPCIONES ---
        app.exception(ApiException.class, (ex, ctx) -> {
            ctx.status(ex.getStatus());
            ctx.json(ApiResponse.error(ex.getStatus(), ex.getMessage(), ex.getDetails()));
        });
        app.exception(Exception.class, (ex, ctx) -> {
            ctx.status(500);
            System.err.println("[ERROR] Ocurrió un error inesperado: " + ex.getMessage());
            ex.printStackTrace(); // Para depuración
            ctx.json(ApiResponse.error(500, "Ocurrió un error inesperado"));
        });
        app.error(404, ctx -> {
            ctx.json(ApiResponse.error(404, "Ruta no encontrada"));
        });

        // --- RUTAS ---
        registerRoutes(app);
    }

    private static void registerRoutes(Javalin app) {
        // --- AUTH ---
        app.post("/login", ctx -> {
            var body = ctx.bodyAsClass(LoginRequest.class);
            handleResponse(ctx, USUARIO_CONTROLLER.login(body.getCorreo(), body.getContrasena()));
        });
        app.post("/registro", ctx -> {
            var b = ctx.bodyAsClass(Payloads.RegistroRequest.class);
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
            handleResponse(ctx, USUARIO_CONTROLLER.registrar(u));
        });
        app.put("/usuarios/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var body = ctx.bodyAsClass(Usuario.class);
            body.setIdUsuario(id);
            handleResponse(ctx, USUARIO_CONTROLLER.actualizarUsuario(body));
        });
        app.delete("/usuarios/{id}", ctx -> {
            int id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, USUARIO_CONTROLLER.eliminarUsuario(id));
        });

        // --- PRODUCTOS ---
        app.get("/productos", ctx -> {
            var q = ctx.queryParam("query");
            var cat = ctx.queryParam("categoria");
            var resp = (q != null || cat != null) ? PRODUCTO_CONTROLLER.buscarProductos(q, cat)
                    : PRODUCTO_CONTROLLER.getAllProductos();
            handleResponse(ctx, resp);
        });
        app.get("/productos/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, PRODUCTO_CONTROLLER.obtenerProducto(id));
        });
        app.get("/admin/productos", ctx -> {
            handleResponse(ctx, PRODUCTO_CONTROLLER.getAllProductos());
        });
        app.post("/admin/productos", ctx -> {
            var producto = ctx.bodyAsClass(Producto.class);
            handleResponse(ctx, PRODUCTO_CONTROLLER.createProducto(producto));
        });
        app.put("/admin/productos/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var producto = ctx.bodyAsClass(Producto.class);
            handleResponse(ctx, PRODUCTO_CONTROLLER.updateProducto(id, producto));
        });
        app.delete("/admin/productos/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, PRODUCTO_CONTROLLER.deleteProducto(id));
        });

        // --- PEDIDOS ---
        app.post("/pedidos", ctx -> {
            var body = ctx.bodyAsClass(PedidoPayload.class);
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
            handleResponse(ctx, PEDIDO_CONTROLLER.crearPedido(pedido, detalles));
        });
        app.get("/pedidos", ctx -> {
            handleResponse(ctx, PEDIDO_CONTROLLER.getPedidos());
        });
        app.get("/pedidos/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, PEDIDO_CONTROLLER.obtenerPedidoConDetalle(id));
        });
        app.get("/pedidos/cliente/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, PEDIDO_CONTROLLER.getPedidosPorCliente(id));
        });
        app.get("/pedidos/estado/{estado}", ctx -> {
            var estado = ctx.pathParam("estado");
            handleResponse(ctx, PEDIDO_CONTROLLER.getPedidosPorEstado(estado));
        });
        app.get("/pedidos/delivery/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, PEDIDO_CONTROLLER.listarPedidosPorDelivery(id));
        });
        app.put("/pedidos/{id}/estado", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var body = ctx.bodyAsClass(EstadoUpdateRequest.class);
            handleResponse(ctx, PEDIDO_CONTROLLER.updateEstadoPedido(id, body.estado));
        });
        app.put("/pedidos/{id}/asignar", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var body = ctx.bodyAsClass(AsignarPedidoRequest.class);
            if (body.idDelivery == null) {
                throw new ApiException(400, "Debe especificar el repartidor");
            }
            handleResponse(ctx, PEDIDO_CONTROLLER.asignarPedido(id, body.idDelivery));
        });

        // --- DELIVERY (REPARTIDOR) ---
        app.get("/pedidos/disponibles", ctx -> {
            handleResponse(ctx, PEDIDO_CONTROLLER.getPedidosPorEstado("pendiente"));
        });

        // --- UBICACIONES ---
        app.post("/ubicaciones", ctx -> {
            var b = ctx.bodyAsClass(Payloads.UbicacionRequest.class);
            var u = toUbicacion(b);
            handleResponse(ctx, UBICACION_CONTROLLER.guardarUbicacion(u));
        });
        app.put("/ubicaciones/{idUbicacion}", ctx -> {
            var id = parseId(ctx.pathParam("idUbicacion"));
            var b = ctx.bodyAsClass(Payloads.UbicacionRequest.class);
            UBICACION_CONTROLLER.actualizarCoordenadas(id, b.getLatitud(), b.getLongitud());
            handleResponse(ctx, ApiResponse.success("Ubicación actualizada correctamente"));
        });
        app.get("/ubicaciones/activas", ctx -> {
            handleResponse(ctx, UBICACION_CONTROLLER.listarActivas());
        });
        app.get("/ubicaciones/usuario/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, UBICACION_CONTROLLER.obtenerUbicacionesPorUsuario(id));
        });

        // --- MENSAJES (CHAT) ---
        app.post("/chat", ctx -> {
            var body = ctx.bodyAsClass(Mensaje.class);
            var result = CHAT_REPOSITORY.guardarMensaje(body);
            if (result.containsKey("error")) {
                handleResponse(ctx, ApiResponse.error(500, "Error al guardar mensaje", result.get("error")));
            } else {
                handleResponse(ctx, ApiResponse.success(201, "Mensaje guardado", result));
            }
        });
        app.get("/chat/{idPedido}", ctx -> {
            var idPedido = parseId(ctx.pathParam("idPedido"));
            var mensajes = CHAT_REPOSITORY.obtenerChatPorPedido(idPedido);
            handleResponse(ctx, ApiResponse.success(200, "Mensajes del chat", mensajes));
        });

        // --- RECOMENDACIONES ---
        app.post("/recomendaciones", ctx -> {
            var body = ctx.bodyAsClass(Recomendacion.class);
            handleResponse(ctx, RECOMENDACION_CONTROLLER.crearRecomendacion(body));
        });
        app.get("/recomendaciones/usuario/{id}", ctx -> {
            var idUsuario = parseId(ctx.pathParam("id"));
            handleResponse(ctx, RECOMENDACION_CONTROLLER.obtenerRecomendacionesPorUsuario(idUsuario));
        });

        // --- TRACKING (SEGUIMIENTO) ---
        app.get("/tracking/pedido/{idPedido}", ctx -> {
            var idPedido = parseId(ctx.pathParam("idPedido"));
            handleResponse(ctx, UBICACION_CONTROLLER.obtenerUbicacionTracking(idPedido));
        });
        app.put("/ubicaciones/repartidor/{idRepartidor}", ctx -> {
            var idRepartidor = parseId(ctx.pathParam("idRepartidor"));
            var body = ctx.bodyAsClass(Payloads.UbicacionRequest.class);
            UBICACION_CONTROLLER.actualizarCoordenadas(idRepartidor, body.getLatitud(), body.getLongitud());
            handleResponse(ctx, ApiResponse.success("Ubicación del repartidor actualizada"));
        });
        // --- GEOCODIFICAR ---
        app.post("/geocodificar", ctx -> {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = (Map<String, Object>) ctx.bodyAsClass(Map.class);
            String direccion = body != null ? (String) body.get("direccion") : null;
            handleResponse(ctx, UBICACION_CONTROLLER.geocodificarDireccion(direccion));
        });

        // --- DASHBOARD ---
        app.get("/admin/stats", ctx -> {
            handleResponse(ctx,
                    ApiResponse.success(200, "Estadísticas admin", DASHBOARD_DAO.obtenerEstadisticasAdmin()));
        });
        app.get("/delivery/stats/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx,
                    ApiResponse.success(200, "Estadísticas delivery", DASHBOARD_DAO.obtenerEstadisticasDelivery(id)));
        });

        // --- CHAT BOT ---
        app.get("/chat/conversaciones/{id}/mensajes", ctx -> {
            var idConversacion = parseId(ctx.pathParam("id"));
            var mensajes = CHAT_REPOSITORY.listarMensajes(idConversacion);
            handleResponse(ctx, ApiResponse.success(200, "Historial de mensajes", mensajes));
        });

        app.post("/chat/bot/mensajes", ctx -> {
            var req = ctx.bodyAsClass(Payloads.ChatBotRequest.class);
            
            // 1. Obtener el ID de la conversación. Prioriza el ID enviado por el cliente.
            // Si el cliente no envía un idConversacion (es nulo o 0), se busca o crea una nueva.
            long idConversacion = (req.idConversacion != null && req.idConversacion > 0)
                    ? req.idConversacion
                    : CHAT_REPOSITORY.ensureBotConversationForUser(req.idRemitente);

            // 2. Guardar el mensaje del usuario
            CHAT_REPOSITORY.insertMensaje(idConversacion, req.idRemitente, null, req.mensaje);

            // 3. Obtener el historial de la conversación para el contexto de la IA
            List<Map<String, Object>> history = CHAT_REPOSITORY.listarMensajes(idConversacion);

            // 4. Generar la respuesta del bot
            String botReply = GEMINI_SERVICE.generateReply(req.mensaje, history, req.idRemitente);

            // 5. Guardar la respuesta del bot (ID de remitente 0 para el bot)
            CHAT_REPOSITORY.insertMensaje(idConversacion, 0, req.idRemitente, botReply);

            // 6. Devolver el ID de la conversación para que el frontend pueda recargar el historial
            Map<String, Object> result = Map.of("id_conversacion", idConversacion);
            handleResponse(ctx, ApiResponse.success(201, "Respuesta generada", result));
        });
    }

    // --- HELPERS ---

    private static void handleResponse(Context ctx, ApiResponse<?> response) {
        ctx.status(response.getStatus());
        ctx.json(response);
    }

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
            throw new ApiException(400, "Identificador inválido: '" + raw + "'");
        }
    }
}
