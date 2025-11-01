package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Negocio;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Acceso a datos para la tabla {@code negocios}.
 */
public class NegocioRepository {

    public Optional<Negocio> findById(int idNegocio) throws SQLException {
        String sql = """
                SELECT id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
                FROM negocios
                WHERE id_negocio = ?
                """;
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idNegocio);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    public Optional<Negocio> findByUsuario(int idUsuario) throws SQLException {
        String sql = """
                SELECT id_negocio, id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo
                FROM negocios
                WHERE id_usuario = ?
                """;
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUsuario);
            try (ResultSet rs = stmt.executeQuery()) {
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
                WHERE LOWER(ruc) = LOWER(?)
                """;
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, ruc);
            try (ResultSet rs = stmt.executeQuery()) {
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
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            List<Negocio> list = new ArrayList<>();
            while (rs.next()) {
                list.add(mapRow(rs));
            }
            return list;
        }
    }

    public Negocio create(Negocio negocio) throws SQLException {
        String sql = """
                INSERT INTO negocios (id_usuario, nombre_comercial, ruc, direccion, telefono, logo_url, activo)
                VALUES (?, ?, ?, ?, ?, ?, COALESCE(?, TRUE))
                RETURNING id_negocio
                """;
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, negocio.getIdUsuario());
            stmt.setString(2, negocio.getNombreComercial());
            stmt.setString(3, negocio.getRuc());
            stmt.setString(4, negocio.getDireccion());
            stmt.setString(5, negocio.getTelefono());
            stmt.setString(6, negocio.getLogoUrl());
            stmt.setBoolean(7, negocio.isActivo());

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    negocio.setIdNegocio(rs.getInt("id_negocio"));
                    return negocio;
                }
            }
        }
        throw new SQLException("No fue posible crear el negocio");
    }

    public boolean update(Negocio negocio) throws SQLException {
        String sql = """
                UPDATE negocios
                SET nombre_comercial = ?, ruc = ?, direccion = ?, telefono = ?, logo_url = ?, activo = ?
                WHERE id_negocio = ?
                """;
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, negocio.getNombreComercial());
            stmt.setString(2, negocio.getRuc());
            stmt.setString(3, negocio.getDireccion());
            stmt.setString(4, negocio.getTelefono());
            stmt.setString(5, negocio.getLogoUrl());
            stmt.setBoolean(6, negocio.isActivo());
            stmt.setInt(7, negocio.getIdNegocio());
            return stmt.executeUpdate() > 0;
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
