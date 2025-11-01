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
import com.mycompany.delivery.api.repository.NegocioRepository;
import com.mycompany.delivery.api.repository.PedidoRepository;
import com.mycompany.delivery.api.repository.RespuestaSoporteRepository;
import com.mycompany.delivery.api.repository.SoporteRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.services.GeminiService;
import com.mycompany.delivery.api.util.ApiResponse;

import io.github.cdimascio.dotenv.Dotenv;
import io.javalin.Javalin;
import io.javalin.http.BadRequestResponse;
import io.javalin.http.Context;
import io.javalin.json.JsonMapper;
import org.jetbrains.annotations.NotNull;

import java.lang.reflect.Type;
import java.sql.SQLException;
import java.util.*;

import static com.mycompany.delivery.api.payloads.Payloads.*;
import com.mycompany.delivery.api.payloads.Payloads.UbicacionesRequest;
import com.mycompany.delivery.api.util.ChatBotResponder;
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
    private static final NegocioController NEGOCIO_CONTROLLER = new NegocioController();
    private static final DashboardDAO DASHBOARD_DAO = new DashboardDAO();
    private static final SoporteRepository SOPORTE_REPO = new SoporteRepository();
    private static final RespuestaSoporteRepository RESPUESTA_SOPORTE_REPO = new RespuestaSoporteRepository();
    private static final ChatRepository CHAT_REPOSITORY = new ChatRepository();
    private static final GeminiService GEMINI_SERVICE = new GeminiService();
    private static final PedidoRepository PEDIDO_REPOSITORY = new PedidoRepository();
    private static final ChatBotResponder CHATBOT_RESPONDER = new ChatBotResponder(GEMINI_SERVICE, PEDIDO_REPOSITORY, CHAT_REPOSITORY);
    private static final NegocioRepository NEGOCIO_REPOSITORY = new NegocioRepository();

    public static void main(String[] args) {
        Dotenv dotenv = Dotenv.load();
        Javalin app = Javalin.create(config -> {
            config.jsonMapper(new JsonMapper() {
                @Override
                public @NotNull String toJsonString(@NotNull Object obj, @NotNull Type type) {
                    return GSON.toJson(obj, type);
                }

                @Override
                public <T> T fromJsonString(@NotNull String json, @NotNull Type targetType) throws JsonSyntaxException {
                    return GSON.fromJson(json, targetType);
                }
            });
            try {
                // Serve static files from classpath '/public' only if present to avoid startup failure.
                java.net.URL res = DeliveryApi.class.getResource("/public");
                if (res != null) {
                    config.staticFiles.add(staticFiles -> {
                        staticFiles.hostedPath = "/";
                        staticFiles.directory = "public";
                        staticFiles.location = io.javalin.http.staticfiles.Location.CLASSPATH;
                    });
                }
            } catch (Exception e) {
                // Ignore missing static resources silently
            }
        }).start(7070);

        app.get("/negocios/{id}/stats", ctx -> {
            long negocioId = Long.parseLong(ctx.pathParam("id"));
            var stats = NEGOCIO_REPOSITORY.getNegocioStats(negocioId);
            handleResponse(ctx, ApiResponse.success(200, "Estadisticas del negocio", stats));
        });

        // =============== AUTHENTICATION ===============
        app.post("/auth/login", ctx -> {
            var body = ctx.bodyAsClass(Payloads.LoginRequest.class);
            handleResponse(ctx, USUARIO_CONTROLLER.login(body.getCorreo(), body.getContrasena()));
        });

        // Registrar el resto de rutas de la API (chat, soporte, tracking, usuarios, etc.)
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
                        "El rol especificado \'" + b.rol + "\' no es vÃ¡lido. Debe ser \'cliente\' o \'repartidor\'.");
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

        // --- NEGOCIO DEL USUARIO ---
        app.get("/usuarios/{id}/negocio", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, NEGOCIO_CONTROLLER.obtenerPorUsuario(id));
        });
        app.post("/usuarios/{id}/negocio", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var negocio = ctx.bodyAsClass(Negocio.class);
            handleResponse(ctx, NEGOCIO_CONTROLLER.registrarONActualizar(id, negocio));
        });
        app.put("/usuarios/{id}/negocio", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var negocio = ctx.bodyAsClass(Negocio.class);
            handleResponse(ctx, NEGOCIO_CONTROLLER.registrarONActualizar(id, negocio));
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

        // --- CATEGORIAS ---
        app.get("/categorias", ctx -> {
            handleResponse(ctx, PRODUCTO_CONTROLLER.obtenerCategorias());
        });

        // --- NEGOCIOS (usa usuarios con rol negocio) ---
        app.get("/admin/negocios", ctx -> {
            var all = USUARIO_CONTROLLER.listarUsuarios();
            // Filtra en memoria a los que sean rol 'negocio'
            @SuppressWarnings("unchecked")
            java.util.List<com.mycompany.delivery.api.model.Usuario> lista = (java.util.List<com.mycompany.delivery.api.model.Usuario>) all
                    .getData();
            var negocios = new java.util.ArrayList<java.util.Map<String, Object>>();
            if (lista != null) {
                for (var u : lista) {
                    if ("negocio".equalsIgnoreCase(u.getRol())) {
                        negocios.add(u.toMap());
                    }
                }
            }
            handleResponse(ctx, ApiResponse.success(200, "Negocios listados", negocios));
        });

        app.post("/admin/negocios", ctx -> {
            var u = ctx.bodyAsClass(Usuario.class);
            if (u.getNombre() == null || u.getCorreo() == null || u.getContrasena() == null) {
                throw new ApiException(400, "nombre, correo y contrase\u00f1a son obligatorios");
            }
            u.setRol("negocio"); // Usamos 'negocio' como rol de negocio
            handleResponse(ctx, USUARIO_CONTROLLER.registrar(u));
        });

        app.get("/admin/negocios/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, USUARIO_CONTROLLER.obtenerPorId(id));
        });

        app.put("/admin/negocios/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var body = ctx.bodyAsClass(Usuario.class);
            body.setIdUsuario(id);
            body.setRol("negocio");
            handleResponse(ctx, USUARIO_CONTROLLER.actualizarUsuario(body));
        });

        app.get("/admin/negocios/{id}/productos", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var negocio = USUARIO_CONTROLLER.obtenerPorId(id).getData();
            if (negocio == null || !"negocio".equalsIgnoreCase(((Usuario) negocio).getRol())) {
                throw new ApiException(404, "Negocio no encontrado");
            }
            var prov = ((Usuario) negocio).getNombre();
            var repo = new com.mycompany.delivery.api.repository.ProductoRepository();
            var lista = repo.listarPorProveedor(prov);
            handleResponse(ctx, ApiResponse.success(200, "Productos del negocio", lista));
        });

        app.post("/admin/negocios/{id}/productos", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            var negocio = USUARIO_CONTROLLER.obtenerPorId(id).getData();
            if (negocio == null || !"negocio".equalsIgnoreCase(((Usuario) negocio).getRol())) {
                throw new ApiException(404, "Negocio no encontrado");
            }
            var prov = ((Usuario) negocio).getNombre();
            var p = ctx.bodyAsClass(Producto.class);
            var repo = new com.mycompany.delivery.api.repository.ProductoRepository();
            var creado = repo.crearProductoParaProveedor(p, prov);
            if (creado.isEmpty())
                throw new ApiException(500, "No se pudo crear el producto");
            handleResponse(ctx, ApiResponse.success(201, "Producto creado para negocio", creado.get()));
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
        // Colocar antes de /pedidos/{id} para que no capture 'disponibles'
        app.get("/pedidos/disponibles", ctx -> {
            handleResponse(ctx, PEDIDO_CONTROLLER.getPedidosPorEstado("pendiente"));
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
            handleResponse(ctx, ApiResponse.success("UbicaciÃ³n actualizada correctamente"));
        });
        app.get("/ubicaciones/activas", ctx -> {
            handleResponse(ctx, UBICACION_CONTROLLER.listarActivas());
        });
        app.get("/ubicaciones/usuario/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, UBICACION_CONTROLLER.obtenerUbicacionesPorUsuario(id));
        });
        app.delete("/ubicaciones/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx, UBICACION_CONTROLLER.eliminarUbicacion(id));
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
        // Endpoint de reseÃ±as por producto
        app.post("/productos/{id}/recomendaciones", ctx -> {
            var idProducto = parseId(ctx.pathParam("id"));
            @SuppressWarnings("unchecked")
            Map<String, Object> body = (Map<String, Object>) ctx.bodyAsClass(Map.class);
            Integer idUsuario = parseNullableInt(body.get("id_usuario"));
            Integer puntuacion = parseNullableInt(body.get("puntuacion"));
            String comentario = body.get("comentario") != null ? body.get("comentario").toString() : null;
            if (idUsuario == null || idUsuario <= 0 || puntuacion == null) {
                throw new ApiException(400, "Debe enviar id_usuario y puntuacion");
            }
            handleResponse(ctx,
                    RECOMENDACION_CONTROLLER.guardarRecomendacion(idProducto, idUsuario, puntuacion, comentario));
        });
        app.get("/recomendaciones", ctx -> {
            handleResponse(ctx, RECOMENDACION_CONTROLLER.listarRecomendacionesDestacadas());
        });
        app.get("/recomendaciones/destacadas", ctx -> {
            handleResponse(ctx, RECOMENDACION_CONTROLLER.listarRecomendacionesDestacadas());
        });
        app.get("/productos/{id}/recomendaciones", ctx -> {
            var idProducto = parseId(ctx.pathParam("id"));
            handleResponse(ctx, RECOMENDACION_CONTROLLER.obtenerResumenYLista(idProducto));
        });
        app.get("/recomendaciones/usuario/{id}", ctx -> {
            var idUsuario = parseId(ctx.pathParam("id"));
            handleResponse(ctx, RECOMENDACION_CONTROLLER.obtenerRecomendacionesPorUsuario(idUsuario));
        });

        // --- TRACKING (SEGUIMIENTO) ---
        app.get("/tracking/pedido/{idPedido}", ctx -> {
            var idPedido = parseId(ctx.pathParam("idPedido"));
            try {
                handleResponse(ctx, UBICACION_CONTROLLER.obtenerUbicacionTracking(idPedido));
            } catch (ApiException ex) {
                if (ex.getStatus() == 404) {
                    handleResponse(ctx,
                            ApiResponse.success(200, "Sin ubicacion de seguimiento", java.util.Collections.emptyMap()));
                } else {
                    throw ex;
                }
            }
        });
        app.get("/tracking/pedido/{idPedido}/ruta", ctx -> {
            var idPedido = parseId(ctx.pathParam("idPedido"));
            try {
                handleResponse(ctx, UBICACION_CONTROLLER.obtenerRutaTracking(idPedido));
            } catch (ApiException ex) {
                if (ex.getStatus() == 404) {
                    handleResponse(ctx,
                            ApiResponse.success(200, "Ruta de seguimiento", java.util.Collections.emptyList()));
                } else {
                    throw ex;
                }
            }
        });
        app.put("/ubicaciones/repartidor/{idRepartidor}", ctx -> {
            var idRepartidor = parseId(ctx.pathParam("idRepartidor"));
            var body = ctx.bodyAsClass(Payloads.UbicacionRequest.class);
            UBICACION_CONTROLLER.actualizarCoordenadas(idRepartidor, body.getLatitud(), body.getLongitud());
            handleResponse(ctx, ApiResponse.success("UbicaciÃ³n del repartidor actualizada"));
        });

        // --- NUEVO ENDPOINT OPTIMIZADO ---
        app.post("/tracking/repartidores/ubicaciones", ctx -> {
            var body = ctx.bodyAsClass(UbicacionesRequest.class);
            if (body.ids == null || body.ids.isEmpty()) {
                throw new BadRequestResponse("La lista de IDs de repartidores es obligatoria.");
            }
            handleResponse(ctx, UBICACION_CONTROLLER.obtenerUbicacionesDeRepartidores(body.ids));
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
                    ApiResponse.success(200, "EstadÃ­sticas admin", DASHBOARD_DAO.obtenerEstadisticasAdmin()));
        });
        app.get("/delivery/stats/{id}", ctx -> {
            var id = parseId(ctx.pathParam("id"));
            handleResponse(ctx,
                    ApiResponse.success(200, "EstadÃƒÂ­sticas delivery", DASHBOARD_DAO.obtenerEstadisticasDelivery(id)));
        });

        // --- SOPORTE ---
        app.post("/soporte/iniciar", ctx -> {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = (Map<String, Object>) ctx.bodyAsClass(Map.class);
            Integer idUsuario = parseNullableInt(body.get("idUsuario"));
            String rol = Objects.toString(body.getOrDefault("rol", "cliente"), "cliente").toLowerCase();

            if (idUsuario == null || idUsuario <= 0) {
                throw new ApiException(400, "idUsuario es obligatorio");
            }
            if (!rol.equals("cliente") && !rol.equals("delivery")) {
                throw new ApiException(400, "rol debe ser 'cliente' o 'delivery'");
            }

            try {
                long idConv = SOPORTE_REPO.ensureSoporteConversacion(idUsuario, rol);
                handleResponse(ctx, ApiResponse.success(201, "Conversacion de soporte iniciada",
                        Map.of("id_conversacion", idConv)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo iniciar la conversacion de soporte", e);
            }
        });

        app.post("/soporte/mensajes", ctx -> {
            Payloads.SoporteMensajeRequest req = ctx.bodyAsClass(Payloads.SoporteMensajeRequest.class);
            if (req == null || req.idConversacion == null || req.idConversacion <= 0) {
                throw new ApiException(400, "idConversacion es obligatorio");
            }
            if (req.idRemitente == null || req.idRemitente <= 0) {
                throw new ApiException(400, "idRemitente es obligatorio");
            }
            String mensaje = Objects.toString(req.mensaje, "").trim();
            if (mensaje.isEmpty()) {
                throw new ApiException(400, "mensaje es obligatorio");
            }

            try {
                SOPORTE_REPO.insertMensajeUsuario(req.idConversacion, req.idRemitente, mensaje);

                Optional<Map<String, Object>> convInfo = SOPORTE_REPO.getInfoConversacion(req.idConversacion);
                String rol = convInfo.map(info -> Objects.toString(info.get("rol"), "cliente")).orElse("cliente");
                boolean esDelivery = "delivery".equalsIgnoreCase(rol);
                boolean esCliente = "cliente".equalsIgnoreCase(rol) || "negocio".equalsIgnoreCase(rol);

                Optional<String> auto = SOPORTE_REPO.buscarAutoRespuesta(mensaje, esCliente, esDelivery);
                if (auto.isPresent()) {
                    int botId = SOPORTE_REPO.ensureBotSoporte();
                    SOPORTE_REPO.insertMensajeSoporte(req.idConversacion, botId, auto.get());
                    handleResponse(ctx, ApiResponse.success(201, "Auto-respuesta enviada",
                            Map.of("id_conversacion", req.idConversacion, "respuesta", auto.get(), "auto", true)));
                } else {
                    handleResponse(ctx, ApiResponse.success(201, "Mensaje guardado; esperando agente humano",
                            Map.of("id_conversacion", req.idConversacion, "auto", false)));
                }
            } catch (SQLException e) {
                throw new ApiException(500, "Error al registrar el mensaje de soporte", e);
            }
        });

        app.get("/soporte/conversaciones/{id}/mensajes", ctx -> {
            long idConv = parseLong(ctx.pathParam("id"));
            try {
                var mensajes = SOPORTE_REPO.listarMensajes(idConv);
                handleResponse(ctx, ApiResponse.success(200, "Historial soporte", mensajes));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo obtener el historial de soporte", e);
            }
        });

        app.get("/soporte/usuario/{idUsuario}/conversaciones", ctx -> {
            int idUsuario = parseId(ctx.pathParam("idUsuario"));
            try {
                var convs = SOPORTE_REPO.listarConversacionesPorUsuario(idUsuario);
                handleResponse(ctx, ApiResponse.success(200, "Conversaciones de soporte", convs));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudieron obtener las conversaciones de soporte", e);
            }
        });

        app.post("/soporte/responder", ctx -> {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = (Map<String, Object>) ctx.bodyAsClass(Map.class);
            Long idConversacion = body.get("idConversacion") instanceof Number n ? n.longValue() : null;
            Integer idSoporte = body.get("idSoporte") instanceof Number n ? n.intValue() : null;
            String mensaje = Objects.toString(body.get("mensaje"), "").trim();

            if (idConversacion == null || idConversacion <= 0) {
                throw new ApiException(400, "idConversacion es obligatorio");
            }
            if (idSoporte == null || idSoporte <= 0) {
                throw new ApiException(400, "idSoporte es obligatorio");
            }
            if (mensaje.isEmpty()) {
                throw new ApiException(400, "mensaje es obligatorio");
            }

            try {
                SOPORTE_REPO.asignarHumano(idConversacion, idSoporte);
                SOPORTE_REPO.insertMensajeSoporte(idConversacion, idSoporte, mensaje);
                handleResponse(ctx,
                        ApiResponse.success(201, "Respuesta enviada", Map.of("id_conversacion", idConversacion)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo registrar la respuesta del agente", e);
            }
        });

        app.post("/soporte/asignar", ctx -> {
            Payloads.SoporteAsignacionRequest req = ctx.bodyAsClass(Payloads.SoporteAsignacionRequest.class);
            if (req.idConversacion == null || req.idConversacion <= 0) {
                throw new ApiException(400, "idConversacion requerido");
            }
            if (req.idAgente == null || req.idAgente <= 0) {
                throw new ApiException(400, "idAgente requerido");
            }
            try {
                SOPORTE_REPO.asignarHumano(req.idConversacion, req.idAgente);
                handleResponse(ctx, ApiResponse.success(200, "Conversacion asignada",
                        Map.of("id_conversacion", req.idConversacion, "id_agente", req.idAgente)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo asignar la conversacion", e);
            }
        });

        app.post("/soporte/cerrar", ctx -> {
            Payloads.SoporteCerrarRequest req = ctx.bodyAsClass(Payloads.SoporteCerrarRequest.class);
            if (req.idConversacion == null || req.idConversacion <= 0) {
                throw new ApiException(400, "idConversacion requerido");
            }
            try {
                SOPORTE_REPO.cerrarConversacion(req.idConversacion);
                handleResponse(ctx, ApiResponse.success(200, "Conversacion cerrada",
                        Map.of("id_conversacion", req.idConversacion)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo cerrar la conversacion", e);
            }
        });

        // --- ADMIN SOPORTE: RESPUESTAS PREDEFINIDAS ---
        app.post("/admin/soporte/respuestas", ctx -> {
            Payloads.SoporteRespuestaPayload payload = ctx.bodyAsClass(Payloads.SoporteRespuestaPayload.class);
            if (payload.categoria == null || payload.categoria.isBlank()) {
                throw new ApiException(400, "categoria requerida");
            }
            if (payload.pregunta == null || payload.pregunta.isBlank()) {
                throw new ApiException(400, "pregunta requerida");
            }
            if (payload.respuesta == null || payload.respuesta.isBlank()) {
                throw new ApiException(400, "respuesta requerida");
            }
            try {
                int id = RESPUESTA_SOPORTE_REPO.crearAutoRespuesta(payload);
                handleResponse(ctx, ApiResponse.success(201, "Respuesta creada", Map.of("id_respuesta", id)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo crear la respuesta predefinida", e);
            }
        });

        app.get("/admin/soporte/respuestas", ctx -> {
            String categoria = ctx.queryParam("categoria");
            try {
                var list = RESPUESTA_SOPORTE_REPO.listarAutoRespuestas(categoria);
                handleResponse(ctx, ApiResponse.success(200, "Respuestas", list));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo listar las respuestas predefinidas", e);
            }
        });

        app.put("/admin/soporte/respuestas/{id}", ctx -> {
            int id = parseId(ctx.pathParam("id"));
            Payloads.SoporteRespuestaPayload payload = ctx.bodyAsClass(Payloads.SoporteRespuestaPayload.class);
            try {
                RESPUESTA_SOPORTE_REPO.actualizarAutoRespuesta(id, payload);
                handleResponse(ctx, ApiResponse.success(200, "Respuesta actualizada", Map.of("id_respuesta", id)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo actualizar la respuesta", e);
            }
        });

        app.delete("/admin/soporte/respuestas/{id}", ctx -> {
            int id = parseId(ctx.pathParam("id"));
            try {
                RESPUESTA_SOPORTE_REPO.borrarAutoRespuesta(id);
                handleResponse(ctx, ApiResponse.success(200, "Respuesta eliminada", Map.of("id_respuesta", id)));
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo eliminar la respuesta", e);
            }
        });

        // --- CHAT BOT ---
        // Conversaciones del usuario
        app.get("/chat/conversaciones/{idUsuario}", ctx -> {
            var idUsuario = parseId(ctx.pathParam("idUsuario"));
            var conversaciones = CHAT_REPOSITORY.listarConversacionesPorUsuario(idUsuario);
            handleResponse(ctx, ApiResponse.success(200, "Conversaciones", conversaciones));
        });

        // Iniciar una conversacion (pedido o libre)
        app.post("/chat/iniciar", ctx -> {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = (Map<String, Object>) ctx.bodyAsClass(Map.class);

            Integer idCliente = parseNullableInt(body.get("idCliente"));
            Integer idDelivery = parseNullableInt(body.get("idDelivery"));
            Integer idAdminSoporte = parseNullableInt(body.get("idAdminSoporte"));
            Integer idPedido = parseNullableInt(body.get("idPedido"));

            if (idCliente == null || idCliente <= 0) {
                throw new ApiException(400, "El campo 'idCliente' es obligatorio");
            }

            long idConversacion;
            if (idPedido != null && idPedido > 0) {
                idConversacion = idPedido.longValue();
                CHAT_REPOSITORY.ensureConversation(idConversacion, idCliente, idDelivery, idAdminSoporte, idPedido,
                        false);
            } else {
                idConversacion = CHAT_REPOSITORY.ensureConversationForUser(idCliente);
                if (idDelivery != null || idAdminSoporte != null) {
                    CHAT_REPOSITORY.ensureConversation(idConversacion, idCliente, idDelivery, idAdminSoporte, null,
                            false);
                }
            }

            Map<String, Object> result = Map.of("id_conversacion", idConversacion);
            handleResponse(ctx, ApiResponse.success(201, "Conversacion iniciada", result));
        });

        // Enviar mensaje (no bot)
        app.post("/chat/mensajes", ctx -> {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = (Map<String, Object>) ctx.bodyAsClass(Map.class);
            Integer idConversacion = parseNullableInt(body.get("idConversacion"));
            Integer idRemitente = parseNullableInt(body.get("idRemitente"));
            Integer idDestinatario = parseNullableInt(body.get("idDestinatario"));
            String mensaje = Objects.toString(body.get("mensaje"), "").trim();

            if (idConversacion == null || idConversacion <= 0) {
                throw new ApiException(400, "El campo 'idConversacion' es obligatorio");
            }
            if (idRemitente == null || idRemitente <= 0) {
                throw new ApiException(400, "El campo 'idRemitente' es obligatorio");
            }
            if (mensaje.isBlank()) {
                throw new ApiException(400, "El campo 'mensaje' es obligatorio");
            }

            var inserted = CHAT_REPOSITORY.insertMensaje(idConversacion.longValue(), idRemitente, idDestinatario,
                    mensaje);
            handleResponse(ctx, ApiResponse.success(201, "Mensaje enviado", inserted));
        });

        app.get("/chat/conversaciones/{id}/mensajes", ctx -> {
            var idConversacion = parseLong(ctx.pathParam("id"));
            var mensajes = CHAT_REPOSITORY.listarMensajes(idConversacion);
            handleResponse(ctx, ApiResponse.success(200, "Historial de mensajes", mensajes));
        });

        app.post("/chat/bot/mensajes", ctx -> {
            var req = ctx.bodyAsClass(Payloads.ChatBotRequest.class);

            // 1. Obtener el ID de la conversaciÃƒÂ³n. Prioriza el ID enviado por el cliente.
            // Si el cliente no envÃƒÂ­a un idConversacion (es nulo o 0), se busca o crea una
            // nueva.
            long idConversacion = (req.idConversacion != null && req.idConversacion > 0) ? req.idConversacion
                    : CHAT_REPOSITORY.ensureBotConversationForUser(req.idRemitente);

            // 2. Guardar el mensaje del usuario
            CHAT_REPOSITORY.insertMensaje(idConversacion, req.idRemitente, null, req.mensaje);

            // 3. Obtener el historial de la conversaciÃƒÂ³n para el contexto de la IA
            List<Map<String, Object>> history = CHAT_REPOSITORY.listarMensajes(idConversacion);

            // 4. Generar la respuesta del bot
            String botReply = CHATBOT_RESPONDER.generateReply(req.mensaje, history, req.idRemitente);

            // 5. Guardar la respuesta del bot usando el usuario del bot
            try {
                int botUserId = CHAT_REPOSITORY.ensureBotUser();
                CHAT_REPOSITORY.insertMensaje(idConversacion, botUserId, req.idRemitente, botReply);
            } catch (SQLException e) {
                throw new ApiException(500, "No se pudo registrar la respuesta del bot", e);
            }

            // 6. Devolver el ID de la conversaciÃƒÂ³n para que el frontend pueda recargar el
            // historial
            Map<String, Object> result = Map.of(
                    "id_conversacion", idConversacion,
                    "bot_reply", botReply);
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
        requireValidCoordinates(r.getLatitud(), r.getLongitud(), "Coordenadas invÃ¡lidas");
        Ubicacion u = new Ubicacion();
        u.setIdUsuario(r.getIdUsuario());
        u.setLatitud(r.getLatitud());
        u.setLongitud(r.getLongitud());
        u.setDireccion(requireNonBlank(r.getDireccion(), "La direcciÃƒÂ³n es obligatoria"));
        u.setDescripcion(normalizeDescripcion(r.getDescripcion()));
        u.setActiva(r.getActiva() == null || r.getActiva());
        return u;
    }

    private static int parseId(String raw) {
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Identificador invalido: '" + raw + "'");
        }
    }

    private static long parseLong(String raw) {
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Identificador invalido: '" + raw + "'");
        }
    }

    private static Integer parseNullableInt(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        String text = value.toString().trim();
        if (text.isEmpty()) {
            return null;
        }
        try {
            return Integer.parseInt(text);
        } catch (NumberFormatException e) {
            throw new ApiException(400, "Valor numerico invalido: '" + text + "'", e);
        }
    }
}
