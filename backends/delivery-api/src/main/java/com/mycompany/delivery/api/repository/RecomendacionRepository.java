package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;

import java.sql.*;
import java.util.*;

public class RecomendacionRepository {

    public boolean guardar(int idProducto, int idUsuario, int puntuacion, String comentario) throws SQLException {
        String sql = "INSERT INTO recomendaciones (id_producto, id_usuario, puntuacion, comentario, fecha) VALUES (?, ?, ?, ?, NOW())";
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idProducto);
            ps.setInt(2, idUsuario);
            ps.setInt(3, puntuacion);
            ps.setString(4, comentario);
            return ps.executeUpdate() > 0;
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
}
