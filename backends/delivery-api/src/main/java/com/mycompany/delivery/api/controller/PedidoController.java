package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.DetallePedido;
import com.mycompany.delivery.api.model.Pedido;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

import java.sql.*;
import java.util.*;

/**
 * Controlador para manejar la lógica de negocio de los pedidos.
 * Se comunica directamente con la base de datos.
 */
public class PedidoController {

    // ===============================
    // CREAR PEDIDO
    // ===============================
    public ApiResponse<Pedido> crearPedido(Pedido pedido, List<DetallePedido> detalles) {
        if (pedido == null || detalles == null || detalles.isEmpty()) {
            throw new ApiException(400, "Datos del pedido incompletos o inválidos");
        }

        String insertPedido = """
            INSERT INTO pedidos (id_cliente, id_delivery, direccion_entrega, metodo_pago, estado, total)
            VALUES (?, ?, ?, ?, ?, ?) RETURNING id_pedido
        """;

        String insertDetalle = """
            INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
            VALUES (?, ?, ?, ?, ?)
        """;

        try (Connection conn = Database.getConnection()) {
            conn.setAutoCommit(false);

            // Insertar pedido
            int idPedido;
            try (PreparedStatement stmt = conn.prepareStatement(insertPedido)) {
                stmt.setInt(1, pedido.getIdCliente());
                if (pedido.getIdDelivery() != null) stmt.setInt(2, pedido.getIdDelivery());
                else stmt.setNull(2, Types.INTEGER);
                stmt.setString(3, pedido.getDireccionEntrega());
                stmt.setString(4, pedido.getMetodoPago());
                stmt.setString(5, pedido.getEstado());
                stmt.setDouble(6, pedido.getTotal());
                ResultSet rs = stmt.executeQuery();
                rs.next();
                idPedido = rs.getInt("id_pedido");
            }

            // Insertar detalles
            try (PreparedStatement stmt = conn.prepareStatement(insertDetalle)) {
                for (DetallePedido d : detalles) {
                    stmt.setInt(1, idPedido);
                    stmt.setInt(2, d.getIdProducto());
                    stmt.setInt(3, d.getCantidad());
                    stmt.setDouble(4, d.getPrecioUnitario());
                    stmt.setDouble(5, d.getSubtotal());
                    stmt.addBatch();
                }
                stmt.executeBatch();
            }

            conn.commit();
            pedido.setIdPedido(idPedido);
            pedido.setDetalles(detalles);

            return ApiResponse.success(201, "Pedido creado correctamente", pedido);

        } catch (SQLException e) {
            throw new ApiException(500, "Error al crear el pedido", e);
        }
    }

    // ===============================
    // LISTAR TODOS LOS PEDIDOS
    // ===============================
    public ApiResponse<List<Pedido>> getPedidos() {
        String sql = "SELECT * FROM pedidos ORDER BY fecha_pedido DESC";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            List<Pedido> pedidos = new ArrayList<>();
            while (rs.next()) {
                Pedido p = new Pedido();
                p.setIdPedido(rs.getInt("id_pedido"));
                p.setIdCliente(rs.getInt("id_cliente"));
                p.setEstado(rs.getString("estado"));
                p.setTotal(rs.getDouble("total"));
                p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
                pedidos.add(p);
            }
            return ApiResponse.success(200, "Pedidos obtenidos correctamente", pedidos);

        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar pedidos", e);
        }
    }

    // ===============================
    // LISTAR POR CLIENTE
    // ===============================
    public ApiResponse<List<Pedido>> getPedidosPorCliente(int idCliente) {
        String sql = "SELECT * FROM pedidos WHERE id_cliente = ? ORDER BY fecha_pedido DESC";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idCliente);
            ResultSet rs = stmt.executeQuery();

            List<Pedido> pedidos = new ArrayList<>();
            while (rs.next()) {
                Pedido p = new Pedido();
                p.setIdPedido(rs.getInt("id_pedido"));
                p.setIdCliente(rs.getInt("id_cliente"));
                p.setEstado(rs.getString("estado"));
                p.setTotal(rs.getDouble("total"));
                p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
                pedidos.add(p);
            }
            return ApiResponse.success(200, "Pedidos por cliente obtenidos", pedidos);

        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener pedidos por cliente", e);
        }
    }

    // ===============================
    // LISTAR POR ESTADO
    // ===============================
    public ApiResponse<List<Pedido>> getPedidosPorEstado(String estado) {
        String sql = "SELECT * FROM pedidos WHERE estado = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, estado);
            ResultSet rs = stmt.executeQuery();

            List<Pedido> pedidos = new ArrayList<>();
            while (rs.next()) {
                Pedido p = new Pedido();
                p.setIdPedido(rs.getInt("id_pedido"));
                p.setIdCliente(rs.getInt("id_cliente"));
                p.setEstado(rs.getString("estado"));
                p.setTotal(rs.getDouble("total"));
                p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
                pedidos.add(p);
            }
            return ApiResponse.success(200, "Pedidos por estado obtenidos", pedidos);

        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar pedidos por estado", e);
        }
    }

    // ===============================
    // ACTUALIZAR ESTADO
    // ===============================
    public ApiResponse<Void> updateEstadoPedido(int idPedido, String nuevoEstado) {
        String sql = "UPDATE pedidos SET estado = ? WHERE id_pedido = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, nuevoEstado);
            stmt.setInt(2, idPedido);
            int rows = stmt.executeUpdate();

            if (rows == 0)
                throw new ApiException(404, "Pedido no encontrado");

            return ApiResponse.success("Estado actualizado correctamente");

        } catch (SQLException e) {
            throw new ApiException(500, "Error al actualizar estado", e);
        }
    }

    // ===============================
    // ASIGNAR DELIVERY
    // ===============================
    public ApiResponse<Void> asignarPedido(int idPedido, int idDelivery) {
        String sql = "UPDATE pedidos SET id_delivery = ? WHERE id_pedido = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);
            stmt.setInt(2, idPedido);
            int rows = stmt.executeUpdate();

            if (rows == 0)
                throw new ApiException(404, "Pedido no encontrado");

            return ApiResponse.success("Pedido asignado correctamente");

        } catch (SQLException e) {
            throw new ApiException(500, "Error al asignar pedido", e);
        }
    }

    // ===============================
    // NUEVOS MÉTODOS PARA DELIVERY
    // ===============================
    public ApiResponse<List<Pedido>> listarPedidosDisponibles() {
        try {
            return ApiResponse.success(200, "Pedidos disponibles", listarPedidosDisponiblesRaw());
        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar pedidos disponibles", e);
        }
    }

    public ApiResponse<List<Pedido>> listarPedidosPorDelivery(int idDelivery) {
        try {
            return ApiResponse.success(200, "Pedidos por delivery", listarPedidosPorDeliveryRaw(idDelivery));
        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar pedidos por delivery", e);
        }
    }

    public ApiResponse<Map<String, Object>> obtenerEstadisticasDelivery(int idDelivery) {
        try {
            return ApiResponse.success(200, "Estadísticas obtenidas", obtenerEstadisticasDeliveryRaw(idDelivery));
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener estadísticas", e);
        }
    }

    // ===============================
    // MÉTODOS INTERNOS SIN ApiResponse
    // ===============================
    private List<Pedido> listarPedidosDisponiblesRaw() throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE estado = 'pendiente'";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            List<Pedido> pedidos = new ArrayList<>();
            while (rs.next()) {
                Pedido p = new Pedido();
                p.setIdPedido(rs.getInt("id_pedido"));
                p.setIdCliente(rs.getInt("id_cliente"));
                p.setEstado(rs.getString("estado"));
                p.setTotal(rs.getDouble("total"));
                p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
                pedidos.add(p);
            }
            return pedidos;
        }
    }

    private List<Pedido> listarPedidosPorDeliveryRaw(int idDelivery) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE id_delivery = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);
            ResultSet rs = stmt.executeQuery();

            List<Pedido> pedidos = new ArrayList<>();
            while (rs.next()) {
                Pedido p = new Pedido();
                p.setIdPedido(rs.getInt("id_pedido"));
                p.setIdCliente(rs.getInt("id_cliente"));
                p.setEstado(rs.getString("estado"));
                p.setTotal(rs.getDouble("total"));
                p.setFechaPedido(rs.getTimestamp("fecha_pedido"));
                pedidos.add(p);
            }
            return pedidos;
        }
    }

    private Map<String, Object> obtenerEstadisticasDeliveryRaw(int idDelivery) throws SQLException {
        String sql = """
            SELECT
              COUNT(*) FILTER (WHERE estado='entregado' AND fecha_entrega::date=CURRENT_DATE)::int AS pedidos_completados_hoy,
              COALESCE(SUM(total) FILTER (WHERE estado='entregado' AND fecha_entrega::date=CURRENT_DATE),0) AS total_generado_hoy,
              AVG(EXTRACT(EPOCH FROM (fecha_entrega - fecha_pedido))/60.0) FILTER (WHERE estado='entregado'
                    AND fecha_entrega IS NOT NULL AND fecha_pedido IS NOT NULL) AS tiempo_promedio_min
            FROM pedidos
            WHERE id_delivery = ?
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);
            ResultSet rs = stmt.executeQuery();

            Map<String, Object> stats = new HashMap<>();
            if (rs.next()) {
                stats.put("pedidos_completados_hoy", rs.getInt("pedidos_completados_hoy"));
                stats.put("total_generado_hoy", rs.getDouble("total_generado_hoy"));
                stats.put("tiempo_promedio_min", rs.getDouble("tiempo_promedio_min"));
            } else {
                stats.put("pedidos_completados_hoy", 0);
                stats.put("total_generado_hoy", 0.0);
                stats.put("tiempo_promedio_min", 0.0);
            }
            return stats;
        }
    }
}
