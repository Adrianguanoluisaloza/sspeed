package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Repositorio especializado para la capa de soporte (tickets independientes
 * del chat general y sin intervención directa de la IA).
 */
public final class SoporteRepository {

    private static final String DEFAULT_CANAL = "app";
    private static final String BOT_EMAIL = "soporte.bot@system.local";
    private static final String BOT_NOMBRE = "Soporte Automático";

    /**
     * Garantiza que exista una conversación abierta para el usuario y rol
     * indicado. Si ya tiene una conversación sin cerrar se reutiliza.
     *
     * @param idUsuario identificador del solicitante.
     * @param rol       rol normalizado (cliente|delivery).
     * @return identificador de la conversación de soporte.
     */
    public long ensureSoporteConversacion(int idUsuario, String rol) throws SQLException {
        try (Connection conn = Database.getConnection()) {
            Long existente = buscarConversacionActiva(conn, idUsuario);
            if (existente != null) {
                return existente;
            }

            String insert = """
                    INSERT INTO soporte_conversaciones (id_usuario, estado, canal, prioridad, permite_ia, created_at, updated_at)
                    VALUES (?, 'abierta', ?, ?, FALSE, NOW(), NOW())
                    RETURNING id_soporte_conv
                    """;
            try (PreparedStatement ps = conn.prepareStatement(insert)) {
                ps.setInt(1, idUsuario);
                ps.setString(2, DEFAULT_CANAL);
                ps.setInt(3, calcularPrioridadInicial(rol));
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        return rs.getLong(1);
                    }
                }
            }
        }
        throw new SQLException("No se pudo crear la conversación de soporte");
    }

    private Long buscarConversacionActiva(Connection conn, int idUsuario) throws SQLException {
        String sql = """
                SELECT id_soporte_conv
                FROM soporte_conversaciones
                WHERE id_usuario = ? AND estado <> 'cerrada'
                ORDER BY updated_at DESC
                LIMIT 1
                """;
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, idUsuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getLong("id_soporte_conv");
                }
            }
        }
        return null;
    }

    private int calcularPrioridadInicial(String rol) {
        if ("delivery".equalsIgnoreCase(rol)) {
            return 2; // un poco más alta
        }
        return 3;
    }

    public void insertMensajeUsuario(long idConversacion, int idRemitente, String mensaje) throws SQLException {
        String sql = """
                INSERT INTO soporte_mensajes (id_soporte_conv, id_remitente, es_agente, tipo, mensaje, created_at)
                VALUES (?, ?, FALSE, 'texto', ?, NOW())
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            ps.setInt(2, idRemitente);
            ps.setString(3, mensaje);
            ps.executeUpdate();
        }
    }

    public void insertMensajeSoporte(long idConversacion, int idSoporte, String mensaje) throws SQLException {
        String sql = """
                INSERT INTO soporte_mensajes (id_soporte_conv, id_remitente, es_agente, tipo, mensaje, created_at)
                VALUES (?, ?, TRUE, 'texto', ?, NOW())
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            ps.setInt(2, idSoporte);
            ps.setString(3, mensaje);
            ps.executeUpdate();
        }
    }

    public Optional<Map<String, Object>> getInfoConversacion(long idConversacion) throws SQLException {
        String sql = """
                SELECT sc.id_soporte_conv,
                       sc.estado,
                       sc.id_agente_soporte,
                       sc.canal,
                       sc.prioridad,
                       sc.permite_ia,
                       sc.id_usuario,
                       u.nombre,
                       LOWER(r.nombre_rol) AS rol
                FROM soporte_conversaciones sc
                LEFT JOIN usuarios u ON sc.id_usuario = u.id_usuario
                LEFT JOIN roles r ON u.id_rol = r.id_rol
                WHERE sc.id_soporte_conv = ?
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> data = new HashMap<>();
                    data.put("id_conversacion", rs.getLong("id_soporte_conv"));
                    data.put("estado", rs.getString("estado"));
                    data.put("id_agente_soporte", rs.getObject("id_agente_soporte"));
                    data.put("canal", rs.getString("canal"));
                    data.put("prioridad", rs.getInt("prioridad"));
                    data.put("permite_ia", rs.getBoolean("permite_ia"));
                    data.put("id_usuario", rs.getObject("id_usuario"));
                    data.put("rol", rs.getString("rol"));
                    data.put("nombre", rs.getString("nombre"));
                    return Optional.of(data);
                }
            }
        }
        return Optional.empty();
    }

    public Optional<String> buscarAutoRespuesta(String mensaje, boolean esCliente, boolean esDelivery)
            throws SQLException {
        String normalizado = mensaje == null ? "" : mensaje.trim();
        if (normalizado.isEmpty()) {
            return Optional.empty();
        }

        List<String> scopes = new ArrayList<>();
        if (esCliente) {
            scopes.add("cliente");
        }
        if (esDelivery) {
            scopes.add("delivery");
        }
        scopes.add("mixto"); // fallback

        String sql = "SELECT respuesta FROM fn_chatbot_match_predef(?, ?, 'soporte', 'es') ORDER BY prioridad LIMIT 1";

        try (Connection conn = Database.getConnection()) {
            for (String scope : scopes) {
                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setString(1, normalizado);
                    ps.setString(2, scope);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            String respuesta = rs.getString("respuesta");
                            if (respuesta != null && !respuesta.isBlank()) {
                                return Optional.of(respuesta.trim());
                            }
                        }
                    }
                }
            }
        }
        return Optional.empty();
    }

    public List<Map<String, Object>> listarMensajes(long idConversacion) throws SQLException {
        String sql = """
                SELECT id_sop_msj,
                       id_soporte_conv,
                       id_remitente,
                       es_agente,
                       tipo,
                       mensaje,
                       created_at
                FROM soporte_mensajes
                WHERE id_soporte_conv = ?
                ORDER BY created_at ASC
                """;
        List<Map<String, Object>> mensajes = new ArrayList<>();
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", rs.getLong("id_sop_msj"));
                    map.put("id_conversacion", rs.getLong("id_soporte_conv"));
                    map.put("id_remitente", rs.getObject("id_remitente"));
                    map.put("es_agente", rs.getBoolean("es_agente"));
                    map.put("tipo", rs.getString("tipo"));
                    map.put("mensaje", rs.getString("mensaje"));
                    Timestamp created = rs.getTimestamp("created_at");
                    map.put("created_at", created != null ? created.toInstant().toString() : null);
                    mensajes.add(map);
                }
            }
        }
        return mensajes;
    }

    public List<Map<String, Object>> listarConversacionesPorUsuario(int idUsuario) throws SQLException {
        String sql = """
                SELECT id_soporte_conv,
                       estado,
                       id_agente_soporte,
                       canal,
                       prioridad,
                       permite_ia,
                       created_at,
                       updated_at
                FROM soporte_conversaciones
                WHERE id_usuario = ?
                ORDER BY updated_at DESC
                """;
        List<Map<String, Object>> lista = new ArrayList<>();
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, idUsuario);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id_conversacion", rs.getLong("id_soporte_conv"));
                    map.put("estado", rs.getString("estado"));
                    map.put("id_agente_soporte", rs.getObject("id_agente_soporte"));
                    map.put("canal", rs.getString("canal"));
                    map.put("prioridad", rs.getInt("prioridad"));
                    map.put("permite_ia", rs.getBoolean("permite_ia"));
                    Timestamp created = rs.getTimestamp("created_at");
                    Timestamp updated = rs.getTimestamp("updated_at");
                    map.put("created_at", created != null ? created.toInstant().toString() : null);
                    map.put("updated_at", updated != null ? updated.toInstant().toString() : null);
                    lista.add(map);
                }
            }
        }
        return lista;
    }

    public void asignarHumano(long idConversacion, int idAgente) throws SQLException {
        String sql = """
                UPDATE soporte_conversaciones
                SET id_agente_soporte = ?, estado = 'asignada', updated_at = NOW()
                WHERE id_soporte_conv = ?
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, idAgente);
            ps.setLong(2, idConversacion);
            ps.executeUpdate();
        }
    }

    public void cerrarConversacion(long idConversacion) throws SQLException {
        String sql = """
                UPDATE soporte_conversaciones
                SET estado = 'cerrada', updated_at = NOW()
                WHERE id_soporte_conv = ?
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, idConversacion);
            ps.executeUpdate();
        }
    }

    public int ensureBotSoporte() throws SQLException {
        final String select = "SELECT id_usuario FROM usuarios WHERE LOWER(correo) = LOWER(?)";
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(select)) {
            ps.setString(1, BOT_EMAIL);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("id_usuario");
                }
            }
        }

        final String insert = """
                INSERT INTO usuarios (nombre, correo, contrasena, id_rol)
                VALUES (?, ?, crypt('soporte_bot', gen_salt('bf')),
                       (SELECT id_rol FROM roles WHERE LOWER(nombre_rol) = 'soporte' LIMIT 1))
                ON CONFLICT (correo) DO NOTHING
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(insert)) {
            ps.setString(1, BOT_NOMBRE);
            ps.setString(2, BOT_EMAIL);
            ps.executeUpdate();
        }

        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(select)) {
            ps.setString(1, BOT_EMAIL);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("id_usuario");
                }
            }
        }
        throw new SQLException("No se pudo crear el bot de soporte");
    }
}
