package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Negocio;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class NegocioRepository {

    public Map<String, Object> getNegocioStats(long negocioId) throws SQLException {
        String sql = """
            SELECT
                COALESCE(SUM(dp.subtotal), 0) AS ingresos_totales,
                COUNT(DISTINCT p.id_pedido) AS pedidos_completados,
                COALESCE(SUM(dp.cantidad), 0) AS productos_vendidos,
                (SELECT COUNT(*) FROM productos WHERE id_negocio = ?) AS total_productos
            FROM pedidos p
            JOIN detalle_pedidos dp ON p.id_pedido = dp.id_pedido
            JOIN productos pr ON dp.id_producto = pr.id_producto
            WHERE pr.id_negocio = ? AND p.estado = 'entregado'
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setLong(1, negocioId);
            ps.setLong(2, negocioId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> stats = new HashMap<>();
                    stats.put("ingresos_totales", rs.getDouble("ingresos_totales"));
                    stats.put("pedidos_completados", rs.getInt("pedidos_completados"));
                    stats.put("productos_vendidos", rs.getInt("productos_vendidos"));
                    stats.put("total_productos", rs.getInt("total_productos"));
                    return stats;
                }
            }
        }
        return Map.of();
    }

    // ================= CRUD / QUERIES PARA NEGOCIOS =================

    public Optional<Negocio> findByUsuario(int idUsuario) throws SQLException {
        String sql = """
            SELECT id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
            FROM negocios
            WHERE id_usuario = ?
            LIMIT 1
        """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, idUsuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    public Optional<Negocio> findByRuc(String ruc) throws SQLException {
        String sql = """
            SELECT id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
            FROM negocios
            WHERE ruc = ?
            LIMIT 1
        """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, ruc);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    public Optional<Negocio> findById(int idNegocio) throws SQLException {
        String sql = """
            SELECT id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
            FROM negocios
            WHERE id_negocio = ?
            LIMIT 1
        """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, idNegocio);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    public List<Negocio> findAll() throws SQLException {
        String sql = """
            SELECT id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
            FROM negocios
            ORDER BY nombre_comercial ASC
        """;
        List<Negocio> list = new ArrayList<>();
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public Negocio create(Negocio n) throws SQLException {
        String sql = """
            INSERT INTO negocios (id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo)
            VALUES (?, ?, ?, ?, ?, ?, COALESCE(?, TRUE))
            RETURNING id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
        """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, n.getIdUsuario());
            ps.setString(2, n.getNombreComercial());
            ps.setString(3, n.getRuc());
            ps.setString(4, n.getDireccion());
            ps.setString(5, n.getTelefono());
            ps.setString(6, n.getLogoUrl());
            ps.setObject(7, n.isActivo());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        throw new SQLException("No se pudo insertar el negocio");
    }

    public void update(Negocio n) throws SQLException {
        String sql = """
            UPDATE negocios
            SET nombre_comercial = ?, ruc = ?, direccion = ?, telefono = ?, logo_url = ?, activo = ?
            WHERE id_negocio = ?
        """;
        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, n.getNombreComercial());
            ps.setString(2, n.getRuc());
            ps.setString(3, n.getDireccion());
            ps.setString(4, n.getTelefono());
            ps.setString(5, n.getLogoUrl());
            ps.setBoolean(6, n.isActivo());
            ps.setInt(7, n.getIdNegocio());
            ps.executeUpdate();
        }
    }

    private Negocio mapRow(ResultSet rs) throws SQLException {
        Negocio n = new Negocio();
        n.setIdNegocio(rs.getInt("id_negocio"));
        n.setIdUsuario(rs.getInt("id_usuario"));
        n.setNombreComercial(rs.getString("nombre_comercial"));
        n.setRuc(rs.getString("ruc"));
        n.setDireccion(rs.getString("direccion"));
        n.setTelefono(rs.getString("telefono"));
        n.setLogoUrl(rs.getString("logo_url"));
        n.setActivo(rs.getBoolean("activo"));
        return n;
    }
}