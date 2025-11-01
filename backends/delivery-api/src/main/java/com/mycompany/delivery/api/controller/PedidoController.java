package com.mycompany.delivery.api.controller;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.DetallePedido;
import com.mycompany.delivery.api.model.Pedido;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

/**
 * Controlador para manejar la lógica de negocio de los pedidos.
 * Se comunica directamente con la base de datos.
 */
public class PedidoController {

    // ===============================
    // CREAR PEDIDO (versión robusta y transaccional)
    // ===============================
    public ApiResponse<Pedido> crearPedido(Pedido pedido, List<DetallePedido> detalles) {
        if (pedido == null || detalles == null || detalles.isEmpty()) {
            throw new ApiException(400, "Datos del pedido incompletos o inválidos");
        }

        // Recalcular el total en el servidor para seguridad
        final double shippingCost = 2.0;
        double subtotal = detalles.stream().mapToDouble(DetallePedido::getSubtotal).sum();
        double totalFinal = subtotal + shippingCost;
        pedido.setTotal(totalFinal); // Actualiza el total en el objeto

        String sqlPedido = """
            INSERT INTO pedidos
            (id_cliente, id_delivery, id_ubicacion, estado, direccion_entrega, metodo_pago, total)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            RETURNING id_pedido
        """;

        // ✅ CORREGIDO: detalle_pedido ➜ detalle_pedidos
        String sqlDetalle = """
            INSERT INTO detalle_pedidos 
            (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
            VALUES (?, ?, ?, ?, ?)
        """;

        try (var conn = Database.getConnection()) {
            conn.setAutoCommit(false);
            int idPedidoGenerado;

            // ==========================
            // 1️⃣ Insertar pedido
            // ==========================
            try (PreparedStatement stmtPedido = conn.prepareStatement(sqlPedido)) {
               stmtPedido.setInt(1, pedido.getIdCliente());

                if (pedido.getIdDelivery() != null) {
                    stmtPedido.setInt(2, pedido.getIdDelivery());
                } else {
                    stmtPedido.setNull(2, Types.INTEGER);
                }

                if (pedido.getIdUbicacion() > 0) {
                    stmtPedido.setInt(3, pedido.getIdUbicacion());
                } else {
                    stmtPedido.setNull(3, Types.INTEGER);
                }

                stmtPedido.setString(4, pedido.getEstado() != null ? pedido.getEstado() : "pendiente");
                stmtPedido.setString(5, pedido.getDireccionEntrega());
                stmtPedido.setString(6, pedido.getMetodoPago());
                stmtPedido.setDouble(7, pedido.getTotal()); // Añadir el total calculado

                try (var rs = stmtPedido.executeQuery()) {
                    if (!rs.next()) {
                        conn.rollback();
                        throw new SQLException("No se generó el ID del pedido");
                    }
                    idPedidoGenerado = rs.getInt("id_pedido");
                }
            }

            // ==========================
            // 2️⃣ Insertar detalles
            // ==========================
            try (var stmtDetalle = conn.prepareStatement(sqlDetalle)) {
                for (var d : detalles) {
                    stmtDetalle.setInt(1, idPedidoGenerado);
                    stmtDetalle.setInt(2, d.getIdProducto());
                    stmtDetalle.setInt(3, d.getCantidad());
                    stmtDetalle.setDouble(4, d.getPrecioUnitario());
                    stmtDetalle.setDouble(5, d.getSubtotal());
                    stmtDetalle.addBatch();
                }
                stmtDetalle.executeBatch();
            }

            // ==========================
            // 3️⃣ Confirmar transacción
            // ==========================
            conn.commit();

            // ==========================
            // 4️⃣ Devolver respuesta
            // ==========================
            pedido.setIdPedido(idPedidoGenerado);
            pedido.setDetalles(detalles);

            return ApiResponse.success(201, "✅ Pedido creado correctamente", pedido);

        } catch (SQLException e) {
            e.printStackTrace();
            throw new ApiException(500, "💥 Error al crear el pedido: " + e.getMessage(), e);
        }
    }

    // ===============================
    // LISTAR TODOS LOS PEDIDOS
    // ===============================
    public ApiResponse<List<Pedido>> getPedidos() {
        String sql = "SELECT * FROM pedidos ORDER BY created_at DESC";
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql);
             var rs = stmt.executeQuery()) {

            var pedidos = new ArrayList<Pedido>();
            while (rs.next()) {
                pedidos.add(mapRowToPedido(rs));
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
        String sql = "SELECT * FROM pedidos WHERE id_cliente = ? ORDER BY created_at DESC";
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idCliente);
            try (var rs = stmt.executeQuery()) {
                var pedidos = new ArrayList<Pedido>();
                while (rs.next()) {
                    pedidos.add(mapRowToPedido(rs));
                }
                return ApiResponse.success(200, "Pedidos por cliente obtenidos", pedidos);
            }

        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener pedidos por cliente", e);
        }
    }

    // ===============================
    // LISTAR POR ESTADO
    // ===============================
    public ApiResponse<List<Pedido>> getPedidosPorEstado(String estado) {
        String sql = "SELECT * FROM pedidos WHERE estado = ?";
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, estado);
            try (var rs = stmt.executeQuery()) {
                var pedidos = new ArrayList<Pedido>();
                while (rs.next()) {
                    pedidos.add(mapRowToPedido(rs));
                }
                return ApiResponse.success(200, "Pedidos por estado obtenidos", pedidos);
            }

        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar pedidos por estado", e);
        }
    }

    // ===============================
    // ACTUALIZAR ESTADO
    // ===============================
    public ApiResponse<Void> updateEstadoPedido(int idPedido, String nuevoEstado) {
        String sql = "UPDATE pedidos SET estado = ? WHERE id_pedido = ?";
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql)) {
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
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql)) {
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

    public ApiResponse<Map<String, Object>> obtenerPedidoConDetalle(int idPedido) {
        if (idPedido <= 0) {
            throw new ApiException(400, "Identificador de pedido invalido");
        }

        String pedidoSql = """
            SELECT id_pedido, id_cliente, id_delivery, id_ubicacion, created_at, updated_at,
                   estado, total, direccion_entrega, metodo_pago, notas, coordenadas_entrega
            FROM pedidos
            WHERE id_pedido = ?
            """;

        String detallesSql = """
            SELECT dp.id_detalle, dp.id_producto, dp.cantidad, dp.precio_unitario, dp.subtotal,
                   pr.nombre AS nombre_producto, pr.imagen_url
            FROM detalle_pedidos dp
            JOIN productos pr ON pr.id_producto = dp.id_producto
            WHERE dp.id_pedido = ?
            ORDER BY dp.id_detalle
            """;

        try (var conn = Database.getConnection();
             var pedidoStmt = conn.prepareStatement(pedidoSql);
             var detalleStmt = conn.prepareStatement(detallesSql)) {

            pedidoStmt.setInt(1, idPedido);
            Map<String, Object> pedidoMap;
            try (var rs = pedidoStmt.executeQuery()) {
                if (rs.next()) {
                    pedidoMap = mapPedido(rs);
                } else {
                    throw new ApiException(404, "Pedido no encontrado con ID: " + idPedido);
                }
            }

            detalleStmt.setInt(1, idPedido);
            List<Map<String, Object>> detalles = new ArrayList<>();
            try (ResultSet rs = detalleStmt.executeQuery()) {
                while (rs.next()) {
                    var det = new HashMap<String, Object>();
                    det.put("id_detalle", rs.getInt("id_detalle"));
                    det.put("id_producto", rs.getInt("id_producto"));
                    det.put("cantidad", rs.getInt("cantidad"));
                    det.put("precio_unitario", rs.getDouble("precio_unitario"));
                    det.put("subtotal", rs.getDouble("subtotal"));
                    det.put("nombre_producto", rs.getString("nombre_producto"));
                    det.put("imagen_url", rs.getString("imagen_url"));
                    detalles.add(det);
                }
            }

            var out = new HashMap<String, Object>();
            out.put("pedido", pedidoMap);
            out.put("detalles", detalles);
            return ApiResponse.success(200, "Pedido obtenido", out);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener el pedido", e);
        }
    }

    public ApiResponse<Map<String, Object>> obtenerEstadisticasDelivery(int idDelivery) {
        try {
            return ApiResponse.success(200, "Estadisticas obtenidas", obtenerEstadisticasDeliveryRaw(idDelivery));
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener estadisticas", e);
        }
    }

    private Map<String, Object> mapPedido(ResultSet rs) throws SQLException {
        var map = new HashMap<String, Object>();
        map.put("id_pedido", rs.getInt("id_pedido"));
        map.put("id_cliente", rs.getInt("id_cliente"));
        map.put("id_delivery", (Integer) rs.getObject("id_delivery"));
        map.put("id_ubicacion", (Integer) rs.getObject("id_ubicacion"));
        map.put("created_at", rs.getTimestamp("created_at"));
        map.put("updated_at", rs.getTimestamp("updated_at"));
        map.put("estado", rs.getString("estado"));
        map.put("total", rs.getDouble("total"));
        map.put("direccion_entrega", rs.getString("direccion_entrega"));
        map.put("metodo_pago", rs.getString("metodo_pago"));
        map.put("notas", rs.getString("notas"));
        map.put("coordenadas_entrega", rs.getString("coordenadas_entrega"));
        return map;
    }

    // ===============================
    // MÉTODOS INTERNOS SIN ApiResponse
    // ===============================
    private List<Pedido> listarPedidosDisponiblesRaw() throws SQLException {
        String sql = "SELECT id_pedido, id_cliente, id_delivery, id_ubicacion, created_at, updated_at, estado, total, direccion_entrega, metodo_pago, notas, coordenadas_entrega FROM pedidos WHERE estado = 'pendiente'";
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql);
             var rs = stmt.executeQuery()) {
            var pedidos = new ArrayList<Pedido>();
            while (rs.next()) {
                pedidos.add(mapRowToPedido(rs));
            }
            return pedidos;
        }
    }

    private List<Pedido> listarPedidosPorDeliveryRaw(int idDelivery) throws SQLException {
        String sql = "SELECT * FROM pedidos WHERE id_delivery = ? ORDER BY created_at DESC";
        try (var conn = Database.getConnection();
             var stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery);
            try (var rs = stmt.executeQuery()) {
                var pedidos = new ArrayList<Pedido>();
                while (rs.next()) {
                    pedidos.add(mapRowToPedido(rs));
                }
                return pedidos;
            }
        }
    }

    private Map<String, Object> obtenerEstadisticasDeliveryRaw(int idDelivery) throws SQLException {
        String sql = """
            SELECT
              COUNT(*) FILTER (WHERE estado='entregado' AND updated_at::date=CURRENT_DATE)::int AS pedidos_completados_hoy,
              COALESCE(SUM(total) FILTER (WHERE estado='entregado' AND updated_at::date=CURRENT_DATE),0) AS total_generado_hoy,
              AVG(EXTRACT(EPOCH FROM (updated_at - created_at))/60.0) FILTER (WHERE estado='entregado' 
                    AND updated_at IS NOT NULL AND created_at IS NOT NULL) AS tiempo_promedio_min
            FROM pedidos
            WHERE id_delivery = ?
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idDelivery); 
            var rs = stmt.executeQuery();

            var stats = new HashMap<String, Object>();
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

    private Pedido mapRowToPedido(ResultSet rs) throws SQLException {
        var p = new Pedido();
        p.setIdPedido(rs.getInt("id_pedido"));
        p.setIdCliente(rs.getInt("id_cliente"));
        p.setIdDelivery((Integer) rs.getObject("id_delivery"));
        p.setIdUbicacion(rs.getInt("id_ubicacion"));
        p.setEstado(rs.getString("estado"));
        p.setTotal(rs.getDouble("total"));
        p.setDireccionEntrega(rs.getString("direccion_entrega"));
        p.setMetodoPago(rs.getString("metodo_pago"));
        p.setFechaPedido(rs.getTimestamp("created_at"));
        p.setFechaEntrega(rs.getTimestamp("updated_at"));
        return p;
    }
}
