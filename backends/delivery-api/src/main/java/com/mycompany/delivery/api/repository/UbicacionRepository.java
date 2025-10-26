package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Ubicacion;
import java.sql.*;
import java.util.*;

/**
 * Repositorio unificado de Ubicaciones.
 * Elimina dependencia de UbicacionDAO y maneja actualizaciones, inserciones y consultas.
 */
public class UbicacionRepository {

    // ===========================
    // CREAR O ACTUALIZAR
    // ===========================
    public Optional<Ubicacion> guardar(Ubicacion ubicacion) throws SQLException {
        String sql = "INSERT INTO ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa, fecha_registro, created_at, updated_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW(), NOW()) RETURNING id_ubicacion";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, ubicacion.getIdUsuario());
            stmt.setDouble(2, ubicacion.getLatitud());
            stmt.setDouble(3, ubicacion.getLongitud());
            stmt.setString(4, ubicacion.getDireccion());
            stmt.setString(5, ubicacion.getDescripcion());
            stmt.setBoolean(6, ubicacion.isActiva());

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    ubicacion.setIdUbicacion(rs.getInt("id_ubicacion"));
                    return Optional.of(ubicacion);
                }
            }
        }
        return Optional.empty();
    }

    // ===========================
    // ACTUALIZAR COORDENADAS POR ID
    // ===========================
    public boolean actualizarUbicacion(int idUbicacion, double latitud, double longitud) throws SQLException {
        String sql = "UPDATE ubicaciones SET latitud = ?, longitud = ?, updated_at = NOW() WHERE id_ubicacion = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, latitud);
            stmt.setDouble(2, longitud);
            stmt.setInt(3, idUbicacion);
            return stmt.executeUpdate() > 0;
        }
    }

    // ===========================
    // ACTUALIZAR UBICACIÓN EN VIVO DE DELIVERY
    // ===========================
    public boolean actualizarUbicacionLive(int idRepartidor, double latitud, double longitud) throws SQLException {
        String sql = "UPDATE usuarios SET latitud_actual = ?, longitud_actual = ? WHERE id_usuario = ? AND rol = 'delivery'";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, latitud);
            stmt.setDouble(2, longitud);
            stmt.setInt(3, idRepartidor);
            return stmt.executeUpdate() > 0;
        }
    }

    // ===========================
    // OBTENER UBICACIÓN POR USUARIO
    // ===========================
    public Optional<Ubicacion> obtenerPorUsuario(int idUsuario) throws SQLException {
        String sql = "SELECT * FROM ubicaciones WHERE id_usuario = ? AND activa = TRUE ORDER BY updated_at DESC LIMIT 1";
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

    // ===========================
    // LISTAR TODAS LAS ACTIVAS
    // ===========================
    public List<Ubicacion> listarActivas() throws SQLException {
        List<Ubicacion> lista = new ArrayList<>();
        String sql = "SELECT * FROM ubicaciones WHERE activa = TRUE ORDER BY updated_at DESC";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                lista.add(mapRow(rs));
            }
        }
        return lista;
    }

    // ===========================
    // ELIMINAR UBICACIÓN
    // ===========================
    public boolean eliminar(int idUbicacion) throws SQLException {
        String sql = "DELETE FROM ubicaciones WHERE id_ubicacion = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUbicacion);
            return stmt.executeUpdate() > 0;
        }
    }

    // ===========================
    // MAPEO RESULTSET → OBJETO
    // ===========================
    private Ubicacion mapRow(ResultSet rs) throws SQLException {
        Ubicacion u = new Ubicacion();
        u.setIdUbicacion(rs.getInt("id_ubicacion"));
        u.setIdUsuario(rs.getInt("id_usuario"));
        u.setLatitud(rs.getDouble("latitud"));
        u.setLongitud(rs.getDouble("longitud"));
        u.setDireccion(rs.getString("direccion"));
        u.setDescripcion(rs.getString("descripcion"));
        u.setActiva(rs.getBoolean("activa"));
        return u;
    }
}