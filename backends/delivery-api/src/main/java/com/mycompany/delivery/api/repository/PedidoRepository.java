package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.DetallePedido;
import com.mycompany.delivery.api.model.Pedido;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Repositorio JDBC para pedidos. Se usa control de transacciones manual para consistencia de detalle.
 */
public class PedidoRepository {

    public int crearPedido(Pedido pedido, List<DetallePedido> detalles) throws SQLException {
        String sqlPedido = "INSERT INTO pedidos (id_cliente, id_delivery, estado, total, direccion_entrega, metodo_pago) VALUES (?, ?, ?, ?, ?, ?)";
        String sqlDetalle = "INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal) VALUES (?, ?, ?, ?, ?)";
        // Almacenar el precio unitario evita diferencias de redondeo al reconstruir tickets en Flutter.

        try (Connection conn = Database.getConnection()) {
            conn.setAutoCommit(false);
            try (PreparedStatement stmtPedido = conn.prepareStatement(sqlPedido, Statement.RETURN_GENERATED_KEYS);
                 PreparedStatement stmtDetalle = conn.prepareStatement(sqlDetalle)) {

                stmtPedido.setInt(1, pedido.getIdCliente());
                if (pedido.getIdDelivery() > 0) {
                    stmtPedido.setInt(2, pedido.getIdDelivery());
                } else {
                    stmtPedido.setNull(2, java.sql.Types.INTEGER);
                }
                stmtPedido.setString(3, pedido.getEstado());
                stmtPedido.setDouble(4, pedido.getTotal());
                stmtPedido.setString(5, pedido.getDireccionEntrega());
                stmtPedido.setString(6, pedido.getMetodoPago());

                if (stmtPedido.executeUpdate() == 0) {
                    conn.rollback();
                    throw new SQLException("No se pudo insertar el pedido");
                }

                int idPedido;
                try (ResultSet generatedKeys = stmtPedido.getGeneratedKeys()) {
                    if (!generatedKeys.next()) {
                        conn.rollback();
                        throw new SQLException("No se obtuvo el ID del pedido");
                    }
                    idPedido = generatedKeys.getInt(1);
                }

                for (DetallePedido detalle : detalles) {
                    stmtDetalle.setInt(1, idPedido);
                    stmtDetalle.setInt(2, detalle.getIdProducto());
                    stmtDetalle.setInt(3, detalle.getCantidad());
                    stmtDetalle.setDouble(4, detalle.getPrecioUnitario());
                    stmtDetalle.setDouble(5, detalle.getSubtotal());
                    stmtDetalle.addBatch();
                }

                stmtDetalle.executeBatch();
                conn.commit();
                return idPedido;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    public List<Pedido> listarPedidos() throws SQLException {
        String sql = "SELECT * FROM pedidos ORDER BY fecha_pedido DESC";
        List<Pedido> pedidos = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                pedidos.add(mapRowToPedido(rs));
            }
        }

        return pedidos;
    }

    public Optional<Pedido> obtenerPedido(int id) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE id_pedido = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRowToPedido(rs));
                }
            }
        }
        return Optional.empty();
    }

    public Optional<Map<String, Object>> obtenerPedidoConDetalles(int idPedido) throws SQLException {
        String sqlPedido = "SELECT * FROM pedidos WHERE id_pedido = ?";
        String sqlDetalles = "SELECT dp.id_producto, dp.cantidad, dp.precio_unitario, dp.subtotal, p.nombre, p.imagen_url FROM detalle_pedido dp JOIN productos p ON dp.id_producto = p.id_producto WHERE dp.id_pedido = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmtPedido = conn.prepareStatement(sqlPedido);
             PreparedStatement stmtDetalle = conn.prepareStatement(sqlDetalles)) {

            stmtPedido.setInt(1, idPedido);
            Pedido pedido;
            try (ResultSet rsPedido = stmtPedido.executeQuery()) {
                if (!rsPedido.next()) {
                    return Optional.empty();
                }
                pedido = mapRowToPedido(rsPedido);
            }

            stmtDetalle.setInt(1, idPedido);
            List<Map<String, Object>> detalles = new ArrayList<>();
            try (ResultSet rsDetalles = stmtDetalle.executeQuery()) {
                while (rsDetalles.next()) {
                    Map<String, Object> detalle = new HashMap<>();
                    detalle.put("id_producto", rsDetalles.getInt("id_producto"));
                    detalle.put("nombre_producto", rsDetalles.getString("nombre"));
                    detalle.put("imagen_url", rsDetalles.getString("imagen_url"));
                    detalle.put("cantidad", rsDetalles.getInt("cantidad"));
                    detalle.put("precio_unitario", rsDetalles.getDouble("precio_unitario"));
                    detalle.put("subtotal", rsDetalles.getDouble("subtotal"));
                    detalles.add(detalle);
                }
            }

            Map<String, Object> resultado = new HashMap<>();
            resultado.put("pedido", pedido);
            resultado.put("detalles", detalles);
            return Optional.of(resultado);
        }
    }

    public List<Pedido> listarPedidosPorEstado(String estado) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE estado = ? ORDER BY fecha_pedido ASC";
        List<Pedido> pedidos = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, estado);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    pedidos.add(mapRowToPedido(rs));
                }
            }
        }

        return pedidos;
    }

    public List<Pedido> listarPedidosPorCliente(int idCliente) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE id_cliente = ? ORDER BY fecha_pedido DESC";
        List<Pedido> pedidos = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idCliente);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    pedidos.add(mapRowToPedido(rs));
                }
            }
        }

        return pedidos;
    }

    public boolean actualizarEstadoPedido(int idPedido, String nuevoEstado) throws SQLException {
        String sql = "UPDATE pedidos SET estado = ? WHERE id_pedido = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, nuevoEstado);
            stmt.setInt(2, idPedido);
            return stmt.executeUpdate() > 0;
        }
    }

    public List<Pedido> listarPedidosDisponibles() throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE estado = 'en preparacion' AND id_delivery IS NULL ORDER BY fecha_pedido ASC";
        List<Pedido> pedidos = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                pedidos.add(mapRowToPedido(rs));
            }
        }
        return pedidos;
    }

    public boolean asignarDelivery(int idPedido, int idDelivery) throws SQLException {
        String sql = "UPDATE pedidos SET id_delivery = ? WHERE id_pedido = ? AND id_delivery IS NULL";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);
            stmt.setInt(2, idPedido);
            return stmt.executeUpdate() > 0;
        }
    }

    public List<Pedido> listarPedidosPorDelivery(int idDelivery) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE id_delivery = ? AND estado IN ('en preparacion', 'en camino') ORDER BY fecha_pedido ASC";
        List<Pedido> pedidos = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    pedidos.add(mapRowToPedido(rs));
                }
            }
        }

        return pedidos;
    }

    public Map<String, Object> obtenerEstadisticasDelivery(int idDelivery) throws SQLException {
        String sql = """
            SELECT
                COUNT(*) FILTER (
                    WHERE estado = 'entregado'
                      AND fecha_entrega::date = CURRENT_DATE
                ) AS pedidos_completados_hoy,
                COALESCE(SUM(total) FILTER (
                    WHERE estado = 'entregado'
                      AND fecha_entrega::date = CURRENT_DATE
                ), 0) AS total_generado_hoy,
                AVG(
                    EXTRACT(EPOCH FROM (fecha_entrega - fecha_pedido)) / 60.0
                ) FILTER (
                    WHERE estado = 'entregado'
                      AND fecha_entrega IS NOT NULL
                      AND fecha_pedido IS NOT NULL
                ) AS tiempo_promedio_min
            FROM pedidos
            WHERE id_delivery = ?
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);

            try (ResultSet rs = stmt.executeQuery()) {
                Map<String, Object> stats = new HashMap<>();
                // Inicializamos con ceros para que el frontend no reciba valores nulos cuando aún no hay registros.
                stats.put("pedidos_completados_hoy", 0);
                stats.put("total_generado_hoy", 0.0);
                stats.put("tiempo_promedio_min", 0.0);

                if (rs.next()) {
                    stats.put("pedidos_completados_hoy", rs.getInt("pedidos_completados_hoy"));
                    stats.put("total_generado_hoy", rs.getDouble("total_generado_hoy"));

                    double tiempoPromedio = rs.getDouble("tiempo_promedio_min");
                    if (!rs.wasNull()) {
                        stats.put("tiempo_promedio_min", tiempoPromedio);
                    }
                }
                return stats;
            }
        }
    }

    private Pedido mapRowToPedido(ResultSet rs) throws SQLException {
        Pedido p = new Pedido();
        p.setIdPedido(rs.getInt("id_pedido"));
        p.setIdCliente(rs.getInt("id_cliente"));
        int idDelivery = rs.getInt("id_delivery");
        if (rs.wasNull()) {
            idDelivery = 0;
        }
        p.setIdDelivery(idDelivery);
        p.setEstado(rs.getString("estado"));
        p.setTotal(rs.getDouble("total"));
        p.setDireccionEntrega(rs.getString("direccion_entrega"));
        p.setMetodoPago(rs.getString("metodo_pago"));
        p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
        return p;
    }
}
