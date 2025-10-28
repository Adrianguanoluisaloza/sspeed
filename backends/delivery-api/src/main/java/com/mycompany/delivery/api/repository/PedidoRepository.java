package com.mycompany.delivery.api.repository;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.DetallePedido;
import com.mycompany.delivery.api.model.Pedido;

/**
 * Repositorio JDBC para operaciones con la tabla pedidos.
 * Controla transacciones al crear pedidos con sus detalles.
 */
public class PedidoRepository {

    public int crearPedido(Pedido pedido, List<DetallePedido> detalles) throws SQLException {
        String sqlPedido = "INSERT INTO pedidos (id_cliente, id_delivery, id_ubicacion, estado, total, direccion_entrega, metodo_pago) VALUES (?, ?, ?, ?, ?, ?, ?)";
    String sqlDetalle = "INSERT INTO detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario, subtotal) VALUES (?, ?, ?, ?, ?)";

        try (Connection conn = Database.getConnection()) {
            conn.setAutoCommit(false);

            try (PreparedStatement stmtPedido = conn.prepareStatement(sqlPedido, Statement.RETURN_GENERATED_KEYS);
                 PreparedStatement stmtDetalle = conn.prepareStatement(sqlDetalle)) {

                stmtPedido.setInt(1, pedido.getIdCliente());
                if (pedido.getIdDelivery() != null) {
                    stmtPedido.setInt(2, pedido.getIdDelivery());
                } else {
                    stmtPedido.setNull(2, Types.INTEGER);
                }
                stmtPedido.setInt(3, pedido.getIdUbicacion());
                stmtPedido.setString(4, pedido.getEstado());
                stmtPedido.setDouble(5, pedido.getTotal());
                stmtPedido.setString(6, pedido.getDireccionEntrega());
                stmtPedido.setString(7, pedido.getMetodoPago());

                if (stmtPedido.executeUpdate() == 0) {
                    conn.rollback();
                    throw new SQLException("No se pudo insertar el pedido");
                }

                int idPedido;
                try (ResultSet rs = stmtPedido.getGeneratedKeys()) {
                    if (!rs.next()) {
                        conn.rollback();
                        throw new SQLException("No se obtuvo el ID del pedido generado");
                    }
                    idPedido = rs.getInt(1);
                }

                for (DetallePedido d : detalles) {
                    stmtDetalle.setInt(1, idPedido);
                    stmtDetalle.setInt(2, d.getIdProducto());
                    stmtDetalle.setInt(3, d.getCantidad());
                    stmtDetalle.setDouble(4, d.getPrecioUnitario());
                    stmtDetalle.setDouble(5, d.getSubtotal());
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

    public Optional<Pedido> obtenerPorId(int idPedido) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE id_pedido = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idPedido);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRowToPedido(rs));
                }
            }
        }
        return Optional.empty();
    }

    public List<Pedido> listarPorCliente(int idCliente) throws SQLException {
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

    public List<Pedido> listarPorEstado(String estado) throws SQLException {
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

    public boolean actualizarEstado(int idPedido, String nuevoEstado) throws SQLException {
        String sql = "UPDATE pedidos SET estado = ?, fecha_entrega = CASE WHEN ? = 'entregado' THEN CURRENT_TIMESTAMP ELSE fecha_entrega END WHERE id_pedido = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, nuevoEstado);
            stmt.setString(2, nuevoEstado);
            stmt.setInt(3, idPedido);
            return stmt.executeUpdate() > 0;
        }
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

    private Pedido mapRowToPedido(ResultSet rs) throws SQLException {
        Pedido p = new Pedido();
        p.setIdPedido(rs.getInt("id_pedido"));
        p.setIdCliente(rs.getInt("id_cliente"));
        p.setIdDelivery(rs.getObject("id_delivery") != null ? rs.getInt("id_delivery") : null);
        p.setIdUbicacion(rs.getInt("id_ubicacion"));
        p.setEstado(rs.getString("estado"));
        p.setTotal(rs.getDouble("total"));
        p.setDireccionEntrega(rs.getString("direccion_entrega"));
        p.setMetodoPago(rs.getString("metodo_pago"));
        p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
        p.setFechaEntrega(rs.getTimestamp("fecha_entrega"));
        return p;
    }
}