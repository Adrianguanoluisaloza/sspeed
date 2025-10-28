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

    private static final String SQL_INSERT = "INSERT INTO recomendaciones (id_producto, id_usuario, puntuacion, comentario, fecha) VALUES (?, ?, ?, ?, NOW())";
    private static final String SQL_UPDATE = "UPDATE recomendaciones SET puntuacion = ?, comentario = ?, fecha = NOW() WHERE id_producto = ? AND id_usuario = ?";

    public boolean guardar(int idProducto, int idUsuario, int puntuacion, String comentario) throws SQLException {
        try (Connection c = Database.getConnection()) {
            boolean previousAutoCommit = c.getAutoCommit();
            if (previousAutoCommit) {
                c.setAutoCommit(false);
            }
            try {
                int updated = actualizarRecomendacion(c, idProducto, idUsuario, puntuacion, comentario);
                if (updated > 0) {
                    if (previousAutoCommit) {
                        c.commit();
                    }
                    return true;
                }
                int inserted = insertarRecomendacion(c, idProducto, idUsuario, puntuacion, comentario);
                if (previousAutoCommit) {
                    c.commit();
                }
                return inserted > 0;
            } catch (SQLException ex) {
                if (previousAutoCommit) {
                    try {
                        c.rollback();
                    } catch (SQLException rollbackEx) {
                        ex.addSuppressed(rollbackEx);
                    }
                }
                throw ex;
            } finally {
                if (previousAutoCommit) {
                    c.setAutoCommit(true);
                }
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
        String sql = "SELECT id_recomendacion, id_producto, id_usuario, puntuacion, comentario, fecha FROM recomendaciones WHERE id_producto = ? ORDER BY fecha DESC";
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

    public List<Map<String, Object>> listarPrincipales() throws SQLException {
        String sql = """
            SELECT r.id_recomendacion, r.id_producto, r.id_usuario, r.comentario, r.puntuacion,
                   r.fecha AS fecha_creacion, p.nombre AS producto, u.nombre AS usuario
            FROM recomendaciones r
            JOIN productos p ON p.id_producto = r.id_producto
            JOIN usuarios  u ON u.id_usuario  = r.id_usuario
            ORDER BY r.puntuacion DESC, r.fecha DESC
            LIMIT 4
            """;

        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            List<Map<String, Object>> list = new ArrayList<>();
            while (rs.next()) {
                Map<String, Object> m = new HashMap<>();
                m.put("id_recomendacion", rs.getInt("id_recomendacion"));
                m.put("id_producto", rs.getInt("id_producto"));
                m.put("id_usuario", rs.getInt("id_usuario"));
                m.put("comentario", rs.getString("comentario"));
                m.put("puntuacion", rs.getInt("puntuacion"));
                m.put("fecha_creacion", rs.getTimestamp("fecha_creacion"));
                m.put("producto", rs.getString("producto"));
                m.put("usuario", rs.getString("usuario"));
                list.add(m);
            }
            return list;
        }
    }
}
