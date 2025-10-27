package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Ubicacion;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class UbicacionRepository {

    // ===============================
    // GUARDAR O ACTUALIZAR UBICACIÓN
    // ===============================
    public Optional<Ubicacion> guardar(Ubicacion ubicacion) throws SQLException {
        String sql = """
            INSERT INTO ubicaciones (id_usuario, latitud, longitud, descripcion, direccion, activa, estado, fecha_registro)
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
            ON CONFLICT (id_usuario) DO UPDATE
            SET latitud = EXCLUDED.latitud,
                longitud = EXCLUDED.longitud,
                descripcion = EXCLUDED.descripcion,
                direccion = EXCLUDED.direccion,
                activa = EXCLUDED.activa,
                estado = EXCLUDED.estado
            RETURNING *;
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, ubicacion.getIdUsuario());
            stmt.setDouble(2, ubicacion.getLatitud());
            stmt.setDouble(3, ubicacion.getLongitud());
            stmt.setString(4, ubicacion.getDescripcion());
            stmt.setString(5, ubicacion.getDireccion());
            stmt.setBoolean(6, ubicacion.isActiva());
            stmt.setString(7, ubicacion.getEstado());

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    // ===============================
    // ACTUALIZAR UBICACIÓN EN VIVO
    // ===============================
    public boolean actualizarUbicacionLive(int idUsuario, double latitud, double longitud) throws SQLException {
        String sql = """
            UPDATE ubicaciones
            SET latitud = ?, longitud = ?, fecha_registro = NOW()
            WHERE id_usuario = ?
        """;
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, latitud);
            stmt.setDouble(2, longitud);
            stmt.setInt(3, idUsuario);
            return stmt.executeUpdate() > 0;
        }
    }

    // ===============================
    // OBTENER UBICACIONES POR USUARIO
    // ===============================
    public List<Ubicacion> obtenerPorUsuario(int idUsuario) throws SQLException {
        List<Ubicacion> lista = new ArrayList<>();
        String sql = "SELECT * FROM ubicaciones WHERE id_usuario = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUsuario);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    lista.add(mapRow(rs));
                }
            }
        }
        return lista;
    }

    // ===============================
    // LISTAR TODAS LAS UBICACIONES ACTIVAS
    // ===============================
    public List<Ubicacion> listarActivas() throws SQLException {
        List<Ubicacion> lista = new ArrayList<>();
        String sql = "SELECT * FROM ubicaciones WHERE activa = TRUE";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                lista.add(mapRow(rs));
            }
        }
        return lista;
    }

    // ===============================
    // ELIMINAR UBICACIÓN
    // ===============================
    public boolean eliminar(int idUbicacion) throws SQLException {
        String sql = "DELETE FROM ubicaciones WHERE id_ubicacion = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUbicacion);
            return stmt.executeUpdate() > 0;
        }
    }

    // ===============================
    // MAPEO RESULTSET → OBJETO
    // ===============================
    private Ubicacion mapRow(ResultSet rs) throws SQLException {
        Ubicacion u = new Ubicacion();
        u.setIdUbicacion(rs.getInt("id_ubicacion"));
        u.setIdUsuario(rs.getInt("id_usuario"));
        u.setLatitud(rs.getDouble("latitud"));
        u.setLongitud(rs.getDouble("longitud"));
        u.setDescripcion(rs.getString("descripcion"));
        u.setDireccion(rs.getString("direccion"));
        u.setActiva(rs.getBoolean("activa"));
        u.setEstado(rs.getString("estado"));
        u.setFechaRegistro(rs.getTimestamp("fecha_registro"));
        return u;
    }
}
