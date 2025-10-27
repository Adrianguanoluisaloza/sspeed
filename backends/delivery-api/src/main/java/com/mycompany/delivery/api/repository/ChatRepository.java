package com.mycompany.delivery.api.repository;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import com.mycompany.delivery.api.config.Database;
import java.util.Map;

public class ChatRepository {

    private static final String BOT_EMAIL = "chatbot@system.local";
    private static final String BOT_NAME = "Asistente Virtual";

    public void ensureConversation(long idConversacion,
                                   Integer idCliente,
                                   Integer idDelivery,
                                   Integer idAdminSoporte,
                                   Integer idPedido) throws SQLException {
        String sql = """
            INSERT INTO chat_conversaciones (id_conversacion, id_pedido, id_cliente, id_delivery, id_admin_soporte, fecha_creacion, activa)
            VALUES (?, ?, ?, ?, ?, NOW(), TRUE)
            ON CONFLICT (id_conversacion) DO UPDATE
            SET id_pedido = COALESCE(chat_conversaciones.id_pedido, EXCLUDED.id_pedido),
                id_cliente = COALESCE(chat_conversaciones.id_cliente, EXCLUDED.id_cliente),
                id_delivery = COALESCE(chat_conversaciones.id_delivery, EXCLUDED.id_delivery),
                id_admin_soporte = COALESCE(chat_conversaciones.id_admin_soporte, EXCLUDED.id_admin_soporte),
                activa = COALESCE(EXCLUDED.activa, chat_conversaciones.activa)
            """;
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            ps.setObject(2, idPedido);
            ps.setObject(3, idCliente);
            ps.setObject(4, idDelivery);
            ps.setObject(5, idAdminSoporte);
            ps.executeUpdate();
        }
    }

    public Map<String, Object> insertMensaje(long idConversacion,
                                             int idRemitente,
                                             Integer idDestinatario,
                                             String mensaje) throws SQLException {
        String sql = """
            INSERT INTO chat_mensajes (id_conversacion, id_remitente, id_destinatario, mensaje, fecha_envio)
            VALUES (?, ?, ?, ?, NOW())
            RETURNING id_mensaje, fecha_envio
            """;
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
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

    public List<Map<String, Object>> listarMensajes(long idConversacion) throws SQLException {
        String sql = """
            SELECT id_mensaje, id_conversacion, id_remitente, id_destinatario, mensaje, fecha_envio
            FROM chat_mensajes
            WHERE id_conversacion = ?
            ORDER BY fecha_envio ASC, id_mensaje ASC
            """;
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
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
                    list.add(row);
                }
                return list;
            }
        }
    }

    public List<Map<String, Object>> listarConversacionesPorUsuario(int idUsuario) throws SQLException {
        String sql = """
            SELECT id_conversacion, id_pedido, id_cliente, id_delivery, id_admin_soporte, fecha_creacion, activa
            FROM chat_conversaciones
            WHERE id_cliente = ? OR id_delivery = ? OR id_admin_soporte = ?
            ORDER BY fecha_creacion DESC
            """;
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
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
                    row.put("fecha_creacion", rs.getTimestamp("fecha_creacion"));
                    row.put("activa", rs.getObject("activa"));
                    list.add(row);
                }
                return list;
            }
        }
    }

    public boolean conversationExists(long idConversacion) throws SQLException {
        String sql = "SELECT 1 FROM chat_conversaciones WHERE id_conversacion = ?";
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    public long ensureConversationForUser(int idUsuario) throws SQLException {
        String sql = """
            SELECT id_conversacion
            FROM chat_conversaciones
            WHERE id_cliente = ? OR id_delivery = ? OR id_admin_soporte = ?
            ORDER BY fecha_creacion DESC
            LIMIT 1
            """;
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
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
        ensureConversation(newId, idUsuario, null, null, null);
        return newId;
    }

    public int ensureBotUser() throws SQLException {
        String select = "SELECT id_usuario FROM usuarios WHERE correo = ?";
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(select)) {
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
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(insert)) {
            ps.setString(1, BOT_NAME);
            ps.setString(2, BOT_EMAIL);
            ps.setString(3, "chatbot123");
            ps.executeUpdate();
        }

        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(select)) {
            ps.setString(1, BOT_EMAIL);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("id_usuario");
                }
            }
        }
        throw new SQLException("No se pudo crear el usuario del chatbot");
    }
}
