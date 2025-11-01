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

public class RecomendacionRepository {

    private static final String SQL_INSERT = "INSERT INTO recomendaciones (id_producto, id_usuario, puntuacion, comentario) VALUES (?, ?, ?, ?)";
    private static final String SQL_UPDATE = "UPDATE recomendaciones SET puntuacion = ?, comentario = ? WHERE id_producto = ? AND id_usuario = ?";

    public boolean guardar(int idProducto, int idUsuario, int puntuacion, String comentario) throws SQLException {
        try (Connection c = Database.getConnection()) {
            try {
                // Intenta insertar primero
                int inserted = insertarRecomendacion(c, idProducto, idUsuario, puntuacion, comentario);
                return inserted > 0;
            } catch (SQLException ex) {
                // Si falla por clave duplicada (UNIQUE constraint), intenta actualizar
                if ("23505".equals(ex.getSQLState())) {
                    int updated = actualizarRecomendacion(c, idProducto, idUsuario, puntuacion, comentario);
                    return updated > 0;
                }
                // Si es otro error, lo relanza
                throw ex;
            }
        }
    }

    private int insertarRecomendacion(Connection c, int idProducto, int idUsuario, int puntuacion, String comentario) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(SQL_INSERT)) {
            ps.setInt(1, idProducto);
            ps.setInt(2, idUsuario);
            ps.setInt(3, puntuacion);
            ps.setString(4, comentario);
            return ps.executeUpdate();
        }
    }

    private int actualizarRecomendacion(Connection c, int idProducto, int idUsuario, int puntuacion, String comentario) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(SQL_UPDATE)) {
            ps.setInt(1, puntuacion);
            ps.setString(2, comentario);
            ps.setInt(3, idProducto);
            ps.setInt(4, idUsuario);
            return ps.executeUpdate();
        }
    }

    public Map<String, Object> resumen(int idProducto) throws SQLException {
        String sql = "SELECT ROUND(AVG(puntuacion)::numeric, 1) AS rating, COUNT(*)::int AS total FROM recomendaciones WHERE id_producto = ?";
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idProducto);
            try (ResultSet rs = ps.executeQuery()) {
                Map<String, Object> out = new HashMap<>();
                out.put("rating", 0.0);
                out.put("total", 0);
                if (rs.next()) {
                    out.put("rating", rs.getDouble("rating"));
                    out.put("total", rs.getInt("total"));
                }
                return out;
            }
        }
    }

    public List<Map<String, Object>> listarPorProducto(int idProducto) throws SQLException {
        String sql = "SELECT id_recomendacion, id_producto, id_usuario, puntuacion, comentario, created_at as fecha FROM recomendaciones WHERE id_producto = ? ORDER BY fecha DESC";
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idProducto);
            try (ResultSet rs = ps.executeQuery()) {
                List<Map<String, Object>> out = new ArrayList<>();
                while (rs.next()) {
                    Map<String, Object> r = new HashMap<>();
                    r.put("id_recomendacion", rs.getInt("id_recomendacion"));
                    r.put("id_producto", rs.getInt("id_producto"));
                    r.put("id_usuario", rs.getInt("id_usuario"));
                    r.put("puntuacion", rs.getInt("puntuacion"));
                    r.put("comentario", rs.getString("comentario"));
                    r.put("fecha", rs.getTimestamp("fecha"));
                    out.add(r);
                }
                return out;
            }
        }
    }

    public List<Map<String, Object>> listarDestacadas() throws SQLException {
        String sql = """
            SELECT
                p.id_producto,
                p.nombre AS producto,
                p.descripcion,
                p.precio,
                p.imagen_url,
                n.nombre_comercial AS negocio,
                ROUND(AVG(r.puntuacion)::numeric, 1) AS rating_promedio,
                COUNT(r.id_recomendacion)::int AS total_reviews,
                MAX(r.created_at) AS ultima_resena,
                (
                    SELECT r2.comentario
                    FROM recomendaciones r2
                    WHERE r2.id_producto = p.id_producto
                      AND r2.comentario IS NOT NULL
                      AND TRIM(r2.comentario) <> ''
                    ORDER BY r2.created_at DESC
                    LIMIT 1
                ) AS comentario_reciente
            FROM recomendaciones r
            JOIN productos p ON p.id_producto = r.id_producto
            LEFT JOIN negocios n ON n.id_negocio = p.id_negocio
            GROUP BY
                p.id_producto,
                p.nombre,
                p.descripcion,
                p.precio,
                p.imagen_url,
                n.nombre_comercial
            ORDER BY rating_promedio DESC, total_reviews DESC, ultima_resena DESC
            LIMIT 10
            """;

        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            List<Map<String, Object>> list = new ArrayList<>();
            while (rs.next()) {
                Map<String, Object> m = new HashMap<>();
                m.put("id_producto", rs.getInt("id_producto"));
                m.put("producto", rs.getString("producto"));
                m.put("descripcion", rs.getString("descripcion"));
                m.put("precio", rs.getBigDecimal("precio"));
                m.put("imagen_url", rs.getString("imagen_url"));
                m.put("negocio", rs.getString("negocio"));
                m.put("rating_promedio", rs.getDouble("rating_promedio"));
                m.put("total_reviews", rs.getInt("total_reviews"));
                m.put("ultima_resena", rs.getTimestamp("ultima_resena"));
                m.put("comentario_reciente", rs.getString("comentario_reciente"));
                list.add(m);
            }
            return list;
        }
    }
}
