package com.mycompany.delivery.api;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Ubicacion;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

// Se eliminaron todos los imports y clases corruptas (LoginRequest, PedidoRequest, etc.)
// que se habían mezclado desde DeliveryApi.java.

import static com.mycompany.delivery.api.util.UbicacionValidator.normalizeActiva;
import static com.mycompany.delivery.api.util.UbicacionValidator.normalizeDescripcion;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireNonBlank;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireValidCoordinates;

/**
 * DAO encargado de persistir y consultar ubicaciones usando JDBC puro.
 * Se reconstruyó tras el merge fallido para devolver una implementación
 * consistente y sin código duplicado.
 */
public class UbicacionDAO {

    private static final String SQL_UPSERT_LIVE = String.join("\n",
            "INSERT INTO ubicaciones (id_usuario, latitud, longitud, descripcion, activa, direccion)",
            "VALUES (?, ?, ?, 'LIVE_TRACKING', false, 'Ubicacion en Vivo')",
            "ON CONFLICT (id_usuario, descripcion) WHERE descripcion = 'LIVE_TRACKING'",
            "DO UPDATE SET",
            "    latitud = EXCLUDED.latitud,",
            "    longitud = EXCLUDED.longitud,",
            "    fecha_registro = CURRENT_TIMESTAMP"
    );

    private static final String SQL_SELECT_LIVE_BY_PEDIDO = String.join("\n",
            "SELECT u.latitud, u.longitud",
            "FROM ubicaciones u",
            "JOIN pedidos p ON u.id_usuario = p.id_delivery",
            "WHERE p.id_pedido = ? AND u.descripcion = 'LIVE_TRACKING' AND p.estado = 'en camino'",
            "LIMIT 1"
    );

    private static final String SQL_SELECT_LIVE_BY_REPARTIDOR = String.join("\n",
            "SELECT latitud, longitud",
            "FROM ubicaciones",
            "WHERE id_usuario = ? AND descripcion = 'LIVE_TRACKING'",
            "LIMIT 1"
    );

    private static final String SQL_UPDATE_COORDENADAS = String.join("\n",
            "UPDATE ubicaciones",
            "SET latitud = ?, longitud = ?",
            "WHERE id_ubicacion = ?"
    );

    private static final String SQL_UPDATE_UBICACION_COMPLETA = String.join("\n",
            "UPDATE ubicaciones",
            "SET latitud = ?, longitud = ?, descripcion = ?, activa = ?, direccion = ?",
            "WHERE id_ubicacion = ? AND id_usuario = ?"
    );

    private static final String SQL_DELETE_UBICACION = "DELETE FROM ubicaciones WHERE id_ubicacion = ?";

    private static final String SQL_INSERT_UBICACION = String.join("\n",
            "INSERT INTO ubicaciones (id_usuario, latitud, longitud, descripcion, activa, direccion)",
            "VALUES (?, ?, ?, ?, ?, ?)",
            "RETURNING id_ubicacion, id_usuario, latitud, longitud, descripcion, direccion, activa"
    );

    private static final String SQL_SELECT_UBICACION_POR_USUARIO = String.join("\n",
            "SELECT id_ubicacion, id_usuario, latitud, longitud, descripcion, direccion, activa",
            "FROM ubicaciones",
            "WHERE id_usuario = ?",
            "ORDER BY id_ubicacion DESC",
            "LIMIT 1"
    );

    private static final String SQL_SELECT_UBICACIONES_ACTIVAS = String.join("\n",
            "SELECT id_ubicacion, id_usuario, latitud, longitud, descripcion, direccion, activa",
            "FROM ubicaciones",
            "WHERE activa = true"
    );

    /**
     * Inserta o actualiza la ubicación en vivo de un repartidor.
     */
    public boolean upsertLiveUbicacion(int idRepartidor, double latitud, double longitud) {
        requireValidCoordinates(latitud, longitud, "Las coordenadas proporcionadas son invalidas");

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmtUpsert = conn.prepareStatement(SQL_UPSERT_LIVE)) {
            
            pstmtUpsert.setInt(1, idRepartidor);
            pstmtUpsert.setDouble(2, latitud);
            pstmtUpsert.setDouble(3, longitud);

            pstmtUpsert.executeUpdate();
            return true;
        } catch (SQLException e) {
            System.err.println("Error al actualizar ubicacion en vivo: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Obtiene la última ubicación en vivo asociada a un pedido.
     */
    public Map<String, Double> getLiveUbicacionByPedido(int idPedido) {
        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_SELECT_LIVE_BY_PEDIDO)) {

            pstmt.setInt(1, idPedido);

            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    Map<String, Double> ubicacion = new HashMap<>();
                    ubicacion.put("latitud", rs.getDouble("latitud"));
                    ubicacion.put("longitud", rs.getDouble("longitud"));
                    return ubicacion;
                }
            }
        } catch (SQLException e) {
            System.err.println("Error en getLiveUbicacionByPedido: " + e.getMessage());
            e.printStackTrace();
        }
        return null;
    }

    /**
     * Obtiene la última ubicación en vivo registrada para un repartidor.
     */
    public Map<String, Double> getUbicacionRepartidor(int idRepartidor) {
        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_SELECT_LIVE_BY_REPARTIDOR)) {

            pstmt.setInt(1, idRepartidor);

            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    Map<String, Double> ubicacion = new HashMap<>();
                    ubicacion.put("latitud", rs.getDouble("latitud"));
                    ubicacion.put("longitud", rs.getDouble("longitud"));
                    return ubicacion;
                }
            }
        } catch (SQLException e) {
            System.err.println("Error en getUbicacionRepartidor: " + e.getMessage());
            e.printStackTrace();
        }
        return null;
    }

    /**
     * Guarda una ubicación completa (no tracking en vivo).
     */
    public Optional<Ubicacion> save(Ubicacion ubicacion) throws SQLException {
        if (ubicacion == null) {
            throw new IllegalArgumentException("La ubicacion no puede ser nula");
        }
        UbicacionRequest sanitized = sanitizeRequest(fromModel(ubicacion));

        if (ubicacion.getIdUbicacion() > 0) {
            boolean updated = updateUbicacionCompleta(ubicacion.getIdUbicacion(), sanitized);
            if (!updated) {
                return Optional.empty();
            }
            return Optional.of(toModel(ubicacion.getIdUbicacion(), sanitized));
        }

        return insert(sanitized);
    }

    /**
     * Versión de conveniencia que mantiene compatibilidad con código existente.
     */
    public boolean insertarUbicacion(Ubicacion ubicacion) throws SQLException {
        return save(ubicacion).isPresent();
    }

    /**
     * Inserta directamente a partir de un request recibido por HTTP.
     */
    public Optional<Ubicacion> insertarUbicacion(UbicacionRequest body) throws SQLException {
        return insert(sanitizeRequest(body));
    }

    /**
     * Actualiza las coordenadas de una ubicación ya existente.
     */
    public boolean actualizarUbicacion(int idUbicacion, double latitud, double longitud) throws SQLException {
        requireValidCoordinates(latitud, longitud, "Las coordenadas proporcionadas son invalidas");

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_UPDATE_COORDENADAS)) {
            pstmt.setDouble(1, latitud);
            pstmt.setDouble(2, longitud);
            pstmt.setInt(3, idUbicacion);
            return pstmt.executeUpdate() > 0;
        }
    }

    /**
     * Obtiene la ubicación más reciente de un usuario.
     */
    public Optional<Ubicacion> obtenerUbicacionPorUsuario(int idUsuario) throws SQLException {
        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_SELECT_UBICACION_POR_USUARIO)) {

            pstmt.setInt(1, idUsuario);

            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapUbicacion(rs));
                }
            }
        }
        return Optional.empty();
    }

    /**
     * Lista todas las ubicaciones activas registradas.
     */
    public List<Ubicacion> listarUbicacionesActivas() throws SQLException {
        List<Ubicacion> ubicaciones = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_SELECT_UBICACIONES_ACTIVAS);
             ResultSet rs = pstmt.executeQuery()) {

            while (rs.next()) {
                ubicaciones.add(mapUbicacion(rs));
            }
        }
        return ubicaciones;
    }

    /**
     * Elimina una ubicación por su identificador.
     */
    public boolean eliminarUbicacion(int idUbicacion) throws SQLException {
        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_DELETE_UBICACION)) {
            pstmt.setInt(1, idUbicacion);
            return pstmt.executeUpdate() > 0;
        }
    }

    private Optional<Ubicacion> insert(UbicacionRequest sanitized) throws SQLException {
        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_INSERT_UBICACION)) {

            pstmt.setInt(1, sanitized.getIdUsuario());
            pstmt.setDouble(2, sanitized.getLatitud());
            pstmt.setDouble(3, sanitized.getLongitud());
            pstmt.setString(4, sanitized.getDescripcion());
            pstmt.setBoolean(5, sanitized.isActiva());
            pstmt.setString(6, sanitized.getDireccion());

            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapUbicacion(rs));
                }
            }
            return Optional.empty();
        } catch (SQLException e) {
            System.err.println("Error al insertar la ubicacion: " + e.getMessage());
            throw e;
        }
    }

    private boolean updateUbicacionCompleta(int idUbicacion, UbicacionRequest sanitized) throws SQLException {
        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(SQL_UPDATE_UBICACION_COMPLETA)) {

            pstmt.setDouble(1, sanitized.getLatitud());
            pstmt.setDouble(2, sanitized.getLongitud());
            pstmt.setString(3, sanitized.getDescripcion());
            pstmt.setBoolean(4, sanitized.isActiva());
            pstmt.setString(5, sanitized.getDireccion());
            pstmt.setInt(6, idUbicacion);
            pstmt.setInt(7, sanitized.getIdUsuario());

            return pstmt.executeUpdate() > 0;
        }
    }

    private static UbicacionRequest fromModel(Ubicacion ubicacion) {
        UbicacionRequest request = new UbicacionRequest();
        request.setIdUsuario(ubicacion.getIdUsuario());
        request.setLatitud(ubicacion.getLatitud());
        request.setLongitud(ubicacion.getLongitud());
        request.setDireccion(ubicacion.getDireccion());
        request.setDescripcion(ubicacion.getDescripcion());
        request.setActiva(ubicacion.isActiva());
        return request;
    }

    private static UbicacionRequest sanitizeRequest(UbicacionRequest body) {
        if (body == null) {
            throw new IllegalArgumentException("La solicitud de ubicacion no puede ser nula");
        }

        Integer idUsuario = body.getIdUsuario();
        if (idUsuario == null || idUsuario <= 0) {
            throw new IllegalArgumentException("El idUsuario es obligatorio y debe ser mayor a cero");
        }

        Double latitud = body.getLatitud();
        Double longitud = body.getLongitud();
        requireValidCoordinates(latitud, longitud, "Las coordenadas proporcionadas son invalidas");

        String direccion = requireNonBlank(body.getDireccion(), "La direccion es obligatoria");
        String descripcion = normalizeDescripcion(body.getDescripcion());
        boolean activa = normalizeActiva(body.getActiva());

        UbicacionRequest sanitized = new UbicacionRequest();
        sanitized.setIdUsuario(idUsuario);
        sanitized.setLatitud(latitud);
        sanitized.setLongitud(longitud);
        sanitized.setDireccion(direccion);
        sanitized.setDescripcion(descripcion);
        sanitized.setActiva(Boolean.valueOf(activa));
        return sanitized;
    }

    private Ubicacion toModel(int idUbicacion, UbicacionRequest sanitized) {
        Ubicacion model = new Ubicacion();
        model.setIdUbicacion(idUbicacion);
        model.setIdUsuario(sanitized.getIdUsuario());
        model.setLatitud(sanitized.getLatitud());
        model.setLongitud(sanitized.getLongitud());
        model.setDescripcion(sanitized.getDescripcion());
        model.setDireccion(sanitized.getDireccion());
        model.setActiva(sanitized.isActiva());
        return model;
    }

    private Ubicacion mapUbicacion(ResultSet rs) throws SQLException {
        Ubicacion ubicacion = new Ubicacion();
        ubicacion.setIdUbicacion(rs.getInt("id_ubicacion"));
        ubicacion.setIdUsuario(rs.getInt("id_usuario"));
        ubicacion.setLatitud(rs.getDouble("latitud"));
        ubicacion.setLongitud(rs.getDouble("longitud"));
        ubicacion.setDescripcion(rs.getString("descripcion"));
        ubicacion.setDireccion(rs.getString("direccion"));
        ubicacion.setActiva(rs.getBoolean("activa"));
        return ubicacion;
    }
}
