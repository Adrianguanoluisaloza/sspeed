package com.mycompany.delivery.api.repository;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.mycompany.delivery.api.config.Database;

/**
 * Repositorio para gestionar las operaciones de la base de datos relacionadas
 * con el chat. Incluye la gestión de conversaciones y mensajes.
 */
public class ChatRepository {

    public ChatRepository() {
        try {
            ensureSchema();
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo inicializar el esquema de chat", e);
        }
    }

    // Método público para guardar un mensaje desde el API
    public Map<String, Object> guardarMensaje(com.mycompany.delivery.api.model.Mensaje mensaje) {
        long idConversacion = mensaje.getIdPedido(); // Se asume que idConversacion = idPedido
        int idPedido = mensaje.getIdPedido();
        int idCliente = mensaje.getIdRemitente(); // Asumimos que el remitente es el cliente

        try {
            // Asegura que la conversación exista antes de insertar el mensaje.
            ensureConversation(idConversacion, idCliente, null, null, idPedido, false);
            return insertMensaje(idConversacion, mensaje.getIdRemitente(), null, mensaje.getMensaje());
        } catch (SQLException e) {
            System.err.println("Error al guardar mensaje: " + e.getMessage());
            return Map.of("error", e.getMessage());
        }
    }

    // Método público para obtener el chat por pedido
    public java.util.List<java.util.Map<String, Object>> obtenerChatPorPedido(int idPedido) {
        try {
            // Buscar la conversación por idPedido
            String sql = "SELECT id_conversacion FROM chat_conversaciones WHERE id_pedido = ? LIMIT 1";
            try (java.sql.Connection c = com.mycompany.delivery.api.config.Database.getConnection();
                    java.sql.PreparedStatement ps = c.prepareStatement(sql)) {
                ps.setInt(1, idPedido);
                try (java.sql.ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        long idConversacion = rs.getLong("id_conversacion");
                        return listarMensajes(idConversacion);
                    }
                }
            }
        } catch (Exception e) {
            return java.util.List.of();
        }
        return java.util.List.of();
    }

    private static final String BOT_EMAIL = "chatbot@system.local";
    private static final String BOT_NAME = "Asistente Virtual";

    /**
     * Asegura que una conversación exista en la base de datos. Si no existe, la
     * crea. Si ya existe, actualiza sus participantes si son nulos.
     *
     * @param idConversacion El identificador único de la conversación.
     * @param idCliente      El ID del cliente participante.
     * @param idDelivery     El ID del repartidor participante.
     * @param idAdminSoporte El ID del administrador de soporte.
     * @param idPedido       El ID del pedido asociado a la conversación.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public void ensureConversation(long idConversacion, Integer idCliente, Integer idDelivery, Integer idAdminSoporte,
            Integer idPedido, boolean esChatbot) throws SQLException {
        String sql = """
                INSERT INTO chat_conversaciones (id_conversacion, id_pedido, id_cliente, id_delivery, id_admin_soporte, es_chatbot, fecha_creacion, activa)
                VALUES (?, ?, ?, ?, ?, ?, NOW(), TRUE)
                ON CONFLICT (id_conversacion) DO UPDATE
                SET id_pedido = COALESCE(chat_conversaciones.id_pedido, EXCLUDED.id_pedido),
                    id_cliente = COALESCE(chat_conversaciones.id_cliente, EXCLUDED.id_cliente),
                    id_delivery = COALESCE(chat_conversaciones.id_delivery, EXCLUDED.id_delivery),
                    id_admin_soporte = COALESCE(chat_conversaciones.id_admin_soporte, EXCLUDED.id_admin_soporte),
                    es_chatbot = COALESCE(chat_conversaciones.es_chatbot, EXCLUDED.es_chatbot),
                    activa = COALESCE(EXCLUDED.activa, chat_conversaciones.activa)
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            ps.setObject(2, idPedido);
            ps.setObject(3, idCliente);
            ps.setObject(4, idDelivery);
            ps.setObject(5, idAdminSoporte);
            ps.setBoolean(6, esChatbot);
            ps.executeUpdate();
        }
    }

    /**
     * Inserta un nuevo mensaje en una conversación.
     *
     * @param idConversacion El ID de la conversación.
     * @param idRemitente    El ID del usuario que envía el mensaje.
     * @param idDestinatario El ID del usuario que recibe el mensaje (puede ser
     *                       nulo).
     * @param mensaje        El contenido del mensaje.
     * @return Un mapa que representa el mensaje insertado, o un mapa vacío si
     *         falla.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public Map<String, Object> insertMensaje(long idConversacion, //
            int idRemitente, Integer idDestinatario, String mensaje) throws SQLException {
        String sql = """
                INSERT INTO chat_mensajes (id_conversacion, id_remitente, id_destinatario, mensaje, fecha_envio)
                VALUES (?, ?, ?, ?, NOW())
                RETURNING id_mensaje, fecha_envio
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            ps.setInt(2, idRemitente);
            ps.setObject(3, idDestinatario);
            ps.setString(4, mensaje);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id_mensaje", rs.getLong("id_mensaje"));
                    map.put("id_conversacion", idConversacion);
                    map.put("id_remitente", idRemitente);
                    map.put("id_destinatario", idDestinatario);
                    map.put("mensaje", mensaje);
                    map.put("fecha_envio", rs.getTimestamp("fecha_envio"));
                    return map;
                }
            }
        }
        return Map.of();
    }

    /**
     * Lista todos los mensajes de una conversación específica, ordenados por fecha.
     *
     * @param idConversacion El ID de la conversación.
     * @return Una lista de mapas, donde cada mapa es un mensaje.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public List<Map<String, Object>> listarMensajes(long idConversacion) throws SQLException {
        String sql = """
                SELECT m.id_mensaje,
                       m.id_conversacion,
                       m.id_remitente,
                       m.id_destinatario,
                       m.mensaje,
                       m.fecha_envio,
                       u.nombre AS remitente_nombre,
                       (LOWER(u.correo) = LOWER(?)) AS es_bot
                FROM chat_mensajes m
                LEFT JOIN usuarios u ON u.id_usuario = m.id_remitente
                WHERE m.id_conversacion = ?
                ORDER BY m.fecha_envio ASC, m.id_mensaje ASC
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, BOT_EMAIL);
            ps.setLong(2, idConversacion);
            try (ResultSet rs = ps.executeQuery()) {
                List<Map<String, Object>> list = new ArrayList<>();
                while (rs.next()) {
                    Map<String, Object> row = new HashMap<>();
                    row.put("id_mensaje", rs.getLong("id_mensaje"));
                    row.put("id_conversacion", rs.getLong("id_conversacion"));
                    row.put("id_remitente", rs.getInt("id_remitente"));
                    row.put("id_destinatario", (Integer) rs.getObject("id_destinatario"));
                    row.put("mensaje", rs.getString("mensaje"));
                    row.put("fecha_envio", rs.getTimestamp("fecha_envio"));
                    row.put("remitente_nombre", rs.getString("remitente_nombre"));
                    row.put("es_bot", rs.getBoolean("es_bot"));
                    list.add(row);
                }
                return list;
            }
        }
    }

    /**
     * Lista todas las conversaciones en las que participa un usuario.
     *
     * @param idUsuario El ID del usuario.
     * @return Una lista de mapas, donde cada mapa representa una conversación.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public List<Map<String, Object>> listarConversacionesPorUsuario(int idUsuario) throws SQLException {
        String sql = """
                SELECT id_conversacion, id_pedido, id_cliente, id_delivery, id_admin_soporte, es_chatbot, fecha_creacion, activa
                FROM chat_conversaciones
                WHERE id_cliente = ? OR id_delivery = ? OR id_admin_soporte = ?
                ORDER BY fecha_creacion DESC
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idUsuario);
            ps.setInt(2, idUsuario);
            ps.setInt(3, idUsuario);
            try (ResultSet rs = ps.executeQuery()) {
                List<Map<String, Object>> list = new ArrayList<>();
                while (rs.next()) {
                    Map<String, Object> row = new HashMap<>();
                    row.put("id_conversacion", rs.getLong("id_conversacion"));
                    row.put("id_pedido", (Integer) rs.getObject("id_pedido"));
                    row.put("id_cliente", (Integer) rs.getObject("id_cliente"));
                    row.put("id_delivery", (Integer) rs.getObject("id_delivery"));
                    row.put("id_admin_soporte", (Integer) rs.getObject("id_admin_soporte"));
                    row.put("es_chatbot", rs.getBoolean("es_chatbot"));
                    row.put("fecha_creacion", rs.getTimestamp("fecha_creacion"));
                    row.put("activa", rs.getObject("activa"));
                    list.add(row);
                }
                return list;
            }
        }
    }

    /**
     * Verifica si una conversación existe.
     *
     * @param idConversacion El ID de la conversación a verificar.
     * @return {@code true} si la conversación existe, {@code false} en caso
     *         contrario.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public boolean conversationExists(long idConversacion) throws SQLException {
        String sql = "SELECT 1 FROM chat_conversaciones WHERE id_conversacion = ?";
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    /**
     * Asegura que un usuario tenga al menos una conversación. Busca la conversación
     * más reciente del usuario. Si no encuentra ninguna, crea una nueva.
     *
     * @param idUsuario El ID del usuario.
     * @return El ID de la conversación existente o recién creada.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public long ensureConversationForUser(int idUsuario) throws SQLException {
        String sql = """
                SELECT id_conversacion
                FROM chat_conversaciones
                WHERE id_cliente = ? OR id_delivery = ? OR id_admin_soporte = ?
                ORDER BY fecha_creacion DESC
                LIMIT 1
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idUsuario);
            ps.setInt(2, idUsuario);
            ps.setInt(3, idUsuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getLong("id_conversacion");
                }
            }
        }
        long newId = System.currentTimeMillis();
        ensureConversation(newId, idUsuario, null, null, null, false);
        return newId;
    }

    /**
     * Asegura que un usuario tenga una conversación exclusiva con el chatbot. Busca
     * una conversación donde el usuario sea el cliente y no haya pedido, repartidor
     * ni soporte asociado (marcador de una conversación de bot). Si no la
     * encuentra, crea una nueva.
     *
     * @param idUsuario El ID del usuario que chatea con el bot.
     * @return El ID de la conversación del bot para ese usuario.
     * @throws SQLException Si ocurre un error en la base de datos.
     */
    public long ensureBotConversationForUser(int idUsuario) throws SQLException {
        // Busca una conversación marcada explícitamente como de chatbot para este
        // usuario.
        String sql = """
                SELECT id_conversacion
                FROM chat_conversaciones
                WHERE id_cliente = ? AND es_chatbot = TRUE
                ORDER BY fecha_creacion DESC
                LIMIT 1
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idUsuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getLong("id_conversacion"); // Devuelve la conversación existente con el bot
                }
            }
        }
        // Si no existe, crea una nueva conversación específica para el bot
        long newId = System.currentTimeMillis();
        ensureConversation(newId, idUsuario, null, null, null, true); // Crea una conversación marcada como chatbot
        return newId;
    }

    /**
     * Asegura que el usuario del "Asistente Virtual" (chatbot) exista en la base de
     * datos. Si no existe, lo crea con el rol de 'soporte'.
     *
     * @return El ID del usuario del chatbot.
     * @throws SQLException Si no se puede crear o encontrar el usuario del bot.
     */
    public int ensureBotUser() throws SQLException {
        String select = "SELECT id_usuario FROM usuarios WHERE correo = ?";
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(select)) {
            ps.setString(1, BOT_EMAIL);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("id_usuario");
                }
            }
        }

        String insert = """
                INSERT INTO usuarios (nombre, correo, contrasena, rol, telefono)
                VALUES (?, ?, ?, 'soporte', '0000000000')
                ON CONFLICT (correo) DO NOTHING
                """;
        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(insert)) {
            ps.setString(1, BOT_NAME);
            ps.setString(2, BOT_EMAIL);
            ps.setString(3, "chatbot123");
            ps.executeUpdate();
        }

        try (Connection c = Database.getConnection(); PreparedStatement ps = c.prepareStatement(select)) {
            ps.setString(1, BOT_EMAIL);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("id_usuario");
                }
            }
        }
        throw new SQLException("No se pudo crear el usuario del chatbot");
    }

    private void ensureSchema() throws SQLException {
        final String createConversaciones = """
                CREATE TABLE IF NOT EXISTS chat_conversaciones (
                    id_conversacion BIGINT PRIMARY KEY,
                    id_pedido INT,
                    id_cliente INT,
                    id_delivery INT,
                    id_admin_soporte INT,
                    fecha_creacion TIMESTAMP DEFAULT NOW(),
                    activa BOOLEAN DEFAULT TRUE
                )
                """;

        final String createMensajes = """
                CREATE TABLE IF NOT EXISTS chat_mensajes (
                    id_mensaje SERIAL PRIMARY KEY,
                    id_conversacion BIGINT NOT NULL REFERENCES chat_conversaciones(id_conversacion) ON DELETE CASCADE,
                    id_remitente INT,
                    id_destinatario INT,
                    mensaje TEXT NOT NULL,
                    fecha_envio TIMESTAMP DEFAULT NOW()
                )
                """;

        final String createIndexConversaciones = """
                CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_cliente
                    ON chat_conversaciones(id_cliente, fecha_creacion DESC)
                """;

        final String createIndexMensajes = """
                CREATE INDEX IF NOT EXISTS idx_chat_mensajes_conversacion
                    ON chat_mensajes(id_conversacion, fecha_envio)
                """;

        try (Connection connection = Database.getConnection();
                java.sql.Statement statement = connection.createStatement()) {
            statement.executeUpdate(createConversaciones);
            statement.executeUpdate(createMensajes);
            statement.executeUpdate(createIndexConversaciones);
            statement.executeUpdate(createIndexMensajes);
        }
    }
}
