package com.mycompany.delivery.api.repository;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.TrackingEvento;
import com.mycompany.delivery.api.model.Ubicacion;

public class UbicacionRepository {

    // ===============================
    // GUARDAR O ACTUALIZAR UBICACIÓN
    // ===============================
    public Optional<Ubicacion> guardar(Ubicacion ubicacion) throws SQLException {
        String sql = """
                    INSERT INTO ubicaciones (id_usuario, latitud, longitud, descripcion, direccion, activa)
                    VALUES (?, ?, ?, ?, ?, ?)
                    RETURNING *;
                """;

        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, ubicacion.getIdUsuario());
            stmt.setDouble(2, ubicacion.getLatitud());
            stmt.setDouble(3, ubicacion.getLongitud());
            stmt.setString(4, ubicacion.getDescripcion());
            stmt.setString(5, ubicacion.getDireccion());
            stmt.setBoolean(6, ubicacion.isActiva());

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
                    UPDATE ubicaciones SET latitud = ?, longitud = ?
                    WHERE id_usuario = ? AND descripcion = 'LIVE_TRACKING'
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, latitud);
            stmt.setDouble(2, longitud);
            stmt.setInt(3, idUsuario);
            int updatedRows = stmt.executeUpdate();
            return updatedRows > 0;
        }
    }

    public void insertarUbicacionLive(int idUsuario, double latitud, double longitud) throws SQLException {
        String sql = """
                INSERT INTO ubicaciones (id_usuario, latitud, longitud, descripcion, activa)
                VALUES (?, ?, ?, 'LIVE_TRACKING', TRUE)
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUsuario);
            stmt.setDouble(2, latitud);
            stmt.setDouble(3, longitud);
            stmt.executeUpdate();
        }
    }

    public void registrarEventoTracking(int idDelivery, double latitud, double longitud) throws SQLException {
        String sql = """
                    INSERT INTO tracking_ruta (id_pedido, latitud, longitud)
                    SELECT p.id_pedido, ?, ?
                    FROM pedidos p
                    WHERE p.id_delivery = ?
                      AND p.estado NOT IN ('entregado', 'cancelado')
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, latitud);
            stmt.setDouble(2, longitud);
            stmt.setInt(3, idDelivery);
            stmt.executeUpdate();
        }
    }

    public Optional<Map<String, Double>> obtenerUbicacionTracking(int idPedido) throws SQLException {
        String sql = """
                SELECT u.latitud, u.longitud FROM ubicaciones u
                JOIN pedidos p ON p.id_delivery = u.id_usuario
                WHERE p.id_pedido = ? AND u.descripcion = 'LIVE_TRACKING'
                ORDER BY u.updated_at DESC LIMIT 1
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement st = conn.prepareStatement(sql)) {
            st.setInt(1, idPedido);
            try (ResultSet rs = st.executeQuery()) {
                if (rs.next()) {
                    return Optional
                            .of(Map.of("latitud", rs.getDouble("latitud"), "longitud", rs.getDouble("longitud")));
                }
            }
        }
        return Optional.empty();
    }

    public List<TrackingEvento> obtenerRutaPedido(int idPedido) throws SQLException {
        List<TrackingEvento> lista = new ArrayList<>();
        String sql = """
                    SELECT id_tracking, id_pedido, latitud, longitud, registrado_en
                    FROM tracking_ruta
                    WHERE id_pedido = ?
                    ORDER BY registrado_en ASC
                """;
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idPedido);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    TrackingEvento evento = new TrackingEvento();
                    evento.setIdPedido(rs.getInt("id_pedido"));
                    evento.setLatitud(rs.getDouble("latitud"));
                    evento.setLongitud(rs.getDouble("longitud"));
                    evento.setFechaEvento(rs.getTimestamp("registrado_en"));
                    lista.add(evento);
                }
            }
        }
        return lista;
    }

    // ===============================
    // OBTENER UBICACIONES POR USUARIO
    // ===============================
    public List<Ubicacion> obtenerPorUsuario(int idUsuario) throws SQLException {
        List<Ubicacion> lista = new ArrayList<>();
        // CORRECCIÓN: Se excluyen las ubicaciones de tracking en vivo, que son de uso
        // interno para el repartidor y no deben mostrarse al usuario como una
        // dirección guardada.
        String sql = "SELECT * FROM ubicaciones WHERE id_usuario = ? AND (descripcion IS NULL OR descripcion != 'LIVE_TRACKING')";
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
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
        // CORRECCIÓN: También se excluyen las ubicaciones de tracking en vivo de
        // este listado general.
        String sql = "SELECT * FROM ubicaciones WHERE activa = TRUE AND (descripcion IS NULL OR descripcion != 'LIVE_TRACKING')";
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
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
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
        // MEJORA: Se lee la fecha de registro directamente.
        // La tabla 'ubicaciones' siempre tiene esta columna, por lo que el try-catch
        // que ignoraba errores no es necesario y podría ocultar problemas.
        u.setFechaRegistro(rs.getTimestamp("created_at"));
        return u;
    }

    public List<Map<String, Object>> obtenerUbicacionesDeRepartidores(List<Integer> repartidorIds) throws SQLException {
        // Prepara la consulta SQL. El `ANY(?)` es la forma en que PostgreSQL maneja
        // la cláusula IN con un array de parámetros.
        String sql = """
                SELECT DISTINCT ON (id_usuario)
                    id_usuario,
                    latitud,
                    longitud
                FROM ubicaciones
                WHERE id_usuario = ANY(?) AND descripcion = 'LIVE_TRACKING'
                ORDER BY id_usuario, updated_at DESC;
                """;

        List<Map<String, Object>> ubicaciones = new ArrayList<>();

        try (Connection conn = Database.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {

            // Convierte la lista de Integer a un array SQL.
            Integer[] idsArray = repartidorIds.toArray(new Integer[0]);
            java.sql.Array sqlArray = conn.createArrayOf("integer", idsArray);
            ps.setArray(1, sqlArray);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ubicaciones.add(Map.of("id_repartidor", rs.getInt("id_usuario"), "latitud", rs.getDouble("latitud"),
                            "longitud", rs.getDouble("longitud")));
                }
            }
        }
        return ubicaciones;
    }
}
