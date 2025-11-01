package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.payloads.Payloads.SoporteRespuestaPayload;

import java.sql.Array;
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

import com.mycompany.delivery.api.model.RespuestaSoporte;

/**
 * Catálogo de respuestas predefinidas para soporte (sin IA).
 */
public final class RespuestaSoporteRepository {

    public int crearAutoRespuesta(SoporteRespuestaPayload payload) throws SQLException {
        if (payload == null) {
            throw new IllegalArgumentException("Payload no puede ser nulo");
        }
        try (Connection conn = Database.getConnection()) {
            Integer categoriaId = ensureCategoria(conn, payload.categoria);
            String sql = """
                    INSERT INTO chatbot_respuestas_predef
                        (id_categoria_bot, canal, scope_destino, intent, keywords, regex_match,
                         respuesta, idioma, tono, prioridad, activo, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, TRUE), NOW(), NOW())
                    RETURNING id_predef
                    """;
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setObject(1, categoriaId);
                ps.setString(2, defaultCanal(payload.canal));
                ps.setString(3, defaultScope(payload.scope));
                ps.setString(4, defaultIntent(payload));
                Array keywordsArray = buildKeywordsArray(conn, payload.keywords);
                if (keywordsArray != null) {
                    ps.setArray(5, keywordsArray);
                } else {
                    ps.setNull(5, java.sql.Types.ARRAY);
                }
                ps.setString(6, normalize(payload.regex));
                ps.setString(7, normalize(payload.respuesta));
                ps.setString(8, defaultIdioma(payload.idioma));
                ps.setString(9, defaultTono(payload.tono));
                ps.setObject(10, defaultPrioridad(payload.prioridad));
                ps.setObject(11, payload.activo);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        return rs.getInt(1);
                    }
                }
            }
        }
        throw new SQLException("No fue posible crear la respuesta predefinida");
    }

    public List<Map<String, Object>> listarAutoRespuestas(String categoria) throws SQLException {
        StringBuilder sql = new StringBuilder("""
                SELECT p.id_predef,
                       c.nombre AS categoria,
                       p.canal,
                       p.scope_destino,
                       p.intent,
                       p.keywords,
                       p.regex_match,
                       p.respuesta,
                       p.idioma,
                       p.tono,
                       p.prioridad,
                       p.activo,
                       p.created_at,
                       p.updated_at
                FROM chatbot_respuestas_predef p
                LEFT JOIN chatbot_categorias c ON p.id_categoria_bot = c.id_categoria_bot
                """);
        boolean filtraCategoria = categoria != null && !categoria.isBlank();
        if (filtraCategoria) {
            sql.append("WHERE LOWER(c.nombre) = LOWER(?)\n");
        }
        sql.append("ORDER BY p.prioridad, p.updated_at DESC");

        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = Database.getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            if (filtraCategoria) {
                ps.setString(1, categoria);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id_respuesta", rs.getLong("id_predef"));
                    map.put("categoria", rs.getString("categoria"));
                    map.put("canal", rs.getString("canal"));
                    map.put("scope", rs.getString("scope_destino"));
                    map.put("intent", rs.getString("intent"));
                    map.put("keywords", rs.getArray("keywords") != null ? rs.getArray("keywords").getArray() : null);
                    map.put("regex", rs.getString("regex_match"));
                    map.put("respuesta", rs.getString("respuesta"));
                    map.put("idioma", rs.getString("idioma"));
                    map.put("tono", rs.getString("tono"));
                    map.put("prioridad", rs.getInt("prioridad"));
                    map.put("activo", rs.getBoolean("activo"));
                    Timestamp created = rs.getTimestamp("created_at");
                    Timestamp updated = rs.getTimestamp("updated_at");
                    map.put("created_at", created != null ? created.toInstant().toString() : null);
                    map.put("updated_at", updated != null ? updated.toInstant().toString() : null);
                    list.add(map);
                }
            }
        }
        return list;
    }

    public Optional<RespuestaSoporte> buscarPorCategoria(String categoria) {
        if (categoria == null || categoria.isBlank()) {
            return Optional.empty();
        }
        String sql = """
                SELECT p.id_predef,
                       COALESCE(c.nombre, '') AS categoria,
                       p.respuesta,
                       p.prioridad
                FROM chatbot_respuestas_predef p
                LEFT JOIN chatbot_categorias c ON p.id_categoria_bot = c.id_categoria_bot
                WHERE p.activo = TRUE
                  AND LOWER(COALESCE(c.nombre, '')) = LOWER(?)
                ORDER BY p.prioridad ASC, p.updated_at DESC
                LIMIT 1
                """;
        try (Connection conn = Database.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, categoria);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRespuesta(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("Error buscando respuesta por categoria: " + e.getMessage());
        }
        return Optional.empty();
    }

    public Optional<RespuestaSoporte> buscarPorTextoCercano(String texto) {
        if (texto == null || texto.isBlank()) {
            return Optional.empty();
        }
        String sql = "SELECT id_predef, respuesta, prioridad FROM fn_chatbot_match_predef(?, ?, 'soporte', 'es') ORDER BY prioridad LIMIT 1";
        List<String> scopes = List.of("cliente", "mixto", "delivery");
        try (Connection conn = Database.getConnection()) {
            for (String scope : scopes) {
                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setString(1, texto);
                    ps.setString(2, scope);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            RespuestaSoporte respuesta = new RespuestaSoporte();
                            respuesta.setIdRespuesta(rs.getInt("id_predef"));
                            respuesta.setCategoria(scope);
                            respuesta.setMensaje(rs.getString("respuesta"));
                            respuesta.setPrioridad(rs.getInt("prioridad"));
                            respuesta.setConMarca(false);
                            return Optional.of(respuesta);
                        }
                    }
                }
            }
        } catch (SQLException e) {
            System.err.println("Error buscando respuesta similar: " + e.getMessage());
        }
        return Optional.empty();
    }

    public void actualizarAutoRespuesta(int id, SoporteRespuestaPayload payload) throws SQLException {
        if (payload == null) {
            return;
        }
        try (Connection conn = Database.getConnection()) {
            Integer categoriaId = payload.categoria != null && !payload.categoria.isBlank()
                    ? ensureCategoria(conn, payload.categoria)
                    : null;
            String sql = """
                    UPDATE chatbot_respuestas_predef
                    SET id_categoria_bot = COALESCE(?, id_categoria_bot),
                        canal = COALESCE(?, canal),
                        scope_destino = COALESCE(?, scope_destino),
                        intent = COALESCE(?, intent),
                        keywords = COALESCE(?, keywords),
                        regex_match = COALESCE(?, regex_match),
                        respuesta = COALESCE(?, respuesta),
                        idioma = COALESCE(?, idioma),
                        tono = COALESCE(?, tono),
                        prioridad = COALESCE(?, prioridad),
                        activo = COALESCE(?, activo),
                        updated_at = NOW()
                    WHERE id_predef = ?
                    """;
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setObject(1, categoriaId);
                ps.setString(2, normalizeOrNull(payload.canal));
                ps.setString(3, normalizeOrNull(payload.scope));
                ps.setString(4, normalizeOrNull(defaultIntent(payload)));
                Array keywordsArray = buildKeywordsArray(conn, payload.keywords);
                if (keywordsArray != null) {
                    ps.setArray(5, keywordsArray);
                } else {
                    ps.setNull(5, java.sql.Types.ARRAY);
                }
                ps.setString(6, normalizeOrNull(payload.regex));
                ps.setString(7, normalizeOrNull(payload.respuesta));
                ps.setString(8, normalizeOrNull(payload.idioma));
                ps.setString(9, normalizeOrNull(payload.tono));
                ps.setObject(10, payload.prioridad);
                ps.setObject(11, payload.activo);
                ps.setInt(12, id);
                ps.executeUpdate();
            }
        }
    }

    public void borrarAutoRespuesta(int id) throws SQLException {
        String sql = """
                UPDATE chatbot_respuestas_predef
                SET activo = FALSE, updated_at = NOW()
                WHERE id_predef = ?
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            ps.executeUpdate();
        }
    }

    private Integer ensureCategoria(Connection conn, String categoria) throws SQLException {
        if (categoria == null || categoria.isBlank()) {
            return null;
        }
        final String select = "SELECT id_categoria_bot FROM chatbot_categorias WHERE LOWER(nombre) = LOWER(?)";
        try (PreparedStatement ps = conn.prepareStatement(select)) {
            ps.setString(1, categoria);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        final String insert = """
                INSERT INTO chatbot_categorias (nombre, descripcion)
                VALUES (?, ?)
                ON CONFLICT (nombre) DO UPDATE SET descripcion = EXCLUDED.descripcion
                RETURNING id_categoria_bot
                """;
        try (PreparedStatement ps = conn.prepareStatement(insert)) {
            ps.setString(1, categoria);
            ps.setString(2, "Autogenerada para soporte");
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return null;
    }

    private static Array buildKeywordsArray(Connection conn, List<String> keywords) throws SQLException {
        if (keywords == null || keywords.isEmpty()) {
            return null;
        }
        List<String> limpias = new ArrayList<>();
        for (String k : keywords) {
            if (k != null && !k.isBlank()) {
                limpias.add(k.trim());
            }
        }
        if (limpias.isEmpty()) {
            return null;
        }
        return conn.createArrayOf("text", limpias.toArray());
    }

    private static String defaultCanal(String canal) {
        return canal == null || canal.isBlank() ? "soporte" : canal.trim().toLowerCase();
    }

    private static String defaultScope(String scope) {
        return scope == null || scope.isBlank() ? "cliente" : scope.trim().toLowerCase();
    }

    private static String defaultIntent(SoporteRespuestaPayload payload) {
        if (payload == null) {
            return null;
        }
        if (payload.intent != null && !payload.intent.isBlank()) {
            return payload.intent.trim();
        }
        if (payload.pregunta != null && !payload.pregunta.isBlank()) {
            return payload.pregunta.trim();
        }
        return null;
    }

    private static String defaultIdioma(String idioma) {
        return idioma == null || idioma.isBlank() ? "es" : idioma.trim().toLowerCase();
    }

    private static String defaultTono(String tono) {
        return tono == null || tono.isBlank() ? "amigable" : tono.trim().toLowerCase();
    }

    private static Short defaultPrioridad(Short prioridad) {
        return prioridad != null ? prioridad : Short.valueOf((short) 3);
    }

    private static String normalize(String value) {
        return value == null ? null : value.trim();
    }

    private static String normalizeOrNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private RespuestaSoporte mapRespuesta(ResultSet rs) throws SQLException {
        RespuestaSoporte respuesta = new RespuestaSoporte();
        respuesta.setIdRespuesta(rs.getInt("id_predef"));
        respuesta.setCategoria(rs.getString("categoria"));
        respuesta.setMensaje(rs.getString("respuesta"));
        respuesta.setPrioridad(rs.getInt("prioridad"));
        respuesta.setConMarca(false);
        return respuesta;
    }
}
