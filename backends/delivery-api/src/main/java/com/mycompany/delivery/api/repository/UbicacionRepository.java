package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Ubicacion;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import static com.mycompany.delivery.api.util.UbicacionValidator.normalizeDescripcion;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireNonBlank;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireValidCoordinates;

/**
 * Repositorio especializado en ubicaciones con validaciones compartidas.
 * Este archivo no tenía conflictos y es la versión limpia que 'UbicacionController' debe usar.
 */
public class UbicacionRepository {

    public static void findLiveTrackingLocationByUsuario(int idRepartidor) {
        // Implementación pendiente.
    }

    public boolean guardarUbicacion(Ubicacion ubicacion) throws SQLException {
        if (ubicacion == null) {
            throw new IllegalArgumentException("La ubicación no puede ser nula");
        }

        if (ubicacion.getIdUbicacion() > 0) {
            return updateExistingUbicacion(ubicacion);
        }
        return save(ubicacion).isPresent();
    }

    public Optional<Ubicacion> obtenerUbicacion(int idUsuario) throws SQLException {
        String sql = """
            SELECT id_ubicacion, id_usuario, latitud, longitud, descripcion, direccion, activa, estado
            FROM ubicaciones
            WHERE id_usuario = ?
            ORDER BY id_ubicacion DESC
            LIMIT 1
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, idUsuario);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapUbicacion(rs));
                }
            }
        }

        return Optional.empty();
    }

    public Optional<Ubicacion> save(Ubicacion ubicacion) throws SQLException {
        validateUbicacion(ubicacion);

        String sql = """
            INSERT INTO ubicaciones (id_usuario, latitud, longitud, descripcion, direccion, activa)
            VALUES (?, ?, ?, ?, ?, ?)
            RETURNING id_ubicacion, id_usuario, latitud, longitud, descripcion, direccion, activa
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {

            pstmt.setInt(1, ubicacion.getIdUsuario());
            pstmt.setDouble(2, ubicacion.getLatitud());
            pstmt.setDouble(3, ubicacion.getLongitud());
            pstmt.setString(4, ubicacion.getDescripcion());
            pstmt.setString(5, ubicacion.getDireccion());
            pstmt.setBoolean(6, ubicacion.isActiva());

            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapUbicacion(rs));
                }
            }
        }

        return Optional.empty();
    }

    public boolean actualizarUbicacion(int idUbicacion, double lat, double lon) throws SQLException {
        requireValidCoordinates(lat, lon, "Las coordenadas proporcionadas son inválidas");

        String sql = """
            UPDATE ubicaciones
            SET latitud = ?, longitud = ?
            WHERE id_ubicacion = ?
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {

            pstmt.setDouble(1, lat);
            pstmt.setDouble(2, lon);
            pstmt.setInt(3, idUbicacion);
            return pstmt.executeUpdate() > 0;
        }
    }

    public boolean eliminarUbicacion(int idUbicacion) throws SQLException {
        String sql = "DELETE FROM ubicaciones WHERE id_ubicacion = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {

            pstmt.setInt(1, idUbicacion);
            return pstmt.executeUpdate() > 0;
        }
    }

    public List<Ubicacion> listarUbicacionesActivas() throws SQLException {
        List<Ubicacion> ubicaciones = new ArrayList<>();
        String sql = """
            SELECT id_ubicacion, id_usuario, latitud, longitud, descripcion, direccion, activa, estado
            FROM ubicaciones
            WHERE activa = true
        """;

        try (Connection conn = Database.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            while (rs.next()) {
                ubicaciones.add(mapUbicacion(rs));
            }
        }

        return ubicaciones;
    }

    private boolean updateExistingUbicacion(Ubicacion ubicacion) throws SQLException {
        if (ubicacion.getIdUbicacion() <= 0) {
            throw new IllegalArgumentException("El idUbicacion es obligatorio para actualizar la ubicación");
        }

        validateUbicacion(ubicacion);

        String sql = """
            UPDATE ubicaciones
            SET latitud = ?, longitud = ?, descripcion = ?, direccion = ?, activa = ?
            WHERE id_ubicacion = ? AND id_usuario = ?
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {

            pstmt.setDouble(1, ubicacion.getLatitud());
            pstmt.setDouble(2, ubicacion.getLongitud());
            pstmt.setString(3, ubicacion.getDescripcion());
            pstmt.setString(4, ubicacion.getDireccion());
            pstmt.setBoolean(5, ubicacion.isActiva());
            pstmt.setInt(6, ubicacion.getIdUbicacion());
            pstmt.setInt(7, ubicacion.getIdUsuario());
            return pstmt.executeUpdate() > 0;
        }
    }

    private void validateUbicacion(Ubicacion ubicacion) {
        if (ubicacion == null) {
            throw new IllegalArgumentException("La ubicación no puede ser nula");
        }
        if (ubicacion.getIdUsuario() <= 0) {
            throw new IllegalArgumentException("El idUsuario es obligatorio y debe ser mayor a cero");
        }

        requireValidCoordinates(ubicacion.getLatitud(), ubicacion.getLongitud(), "Las coordenadas proporcionadas son inválidas");
        ubicacion.setDireccion(requireNonBlank(ubicacion.getDireccion(), "La dirección es obligatoria"));
        ubicacion.setDescripcion(normalizeDescripcion(ubicacion.getDescripcion()));
    }

    private Ubicacion mapUbicacion(ResultSet rs) throws SQLException {
        Ubicacion ubicacion = new Ubicacion();
        ubicacion.setIdUbicacion(rs.getInt("id_ubicacion"));
        ubicacion.setIdUsuario(rs.getInt("id_usuario"));
        ubicacion.setLatitud(rs.getDouble("latitud"));
        ubicacion.setLongitud(rs.getDouble("longitud"));

        if (hasColumn(rs, "descripcion")) {
            ubicacion.setDescripcion(rs.getString("descripcion"));
        }
        if (hasColumn(rs, "direccion")) {
            ubicacion.setDireccion(rs.getString("direccion"));
        }
        if (hasColumn(rs, "activa")) {
            ubicacion.setActiva(rs.getBoolean("activa"));
        }
        if (hasColumn(rs, "estado")) {
            ubicacion.setEstado(rs.getString("estado"));
        }

        return ubicacion;
    }

    private boolean hasColumn(ResultSet rs, String column) throws SQLException {
        ResultSetMetaData metaData = rs.getMetaData();
        for (int i = 1; i <= metaData.getColumnCount(); i++) {
            if (column.equalsIgnoreCase(metaData.getColumnName(i))) {
                return true;
            }
        }
        return false;
    }
}
