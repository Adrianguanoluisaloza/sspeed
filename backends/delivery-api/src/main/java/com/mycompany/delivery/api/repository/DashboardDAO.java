package com.mycompany.delivery.api.repository;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.util.ApiException;

public class DashboardDAO {

    public Map<String, Object> obtenerEstadisticasAdmin() {
        // Intento función consolidada
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement("SELECT * FROM fn_admin_dashboard()");
             ResultSet rs = stmt.executeQuery()) {

            if (rs.next()) return mapStats(rs);
        } catch (SQLException ignored) {}

        // Fallback inline (con CASTs)
        final String inlineSql = """
            WITH ventas AS (
                SELECT COALESCE(SUM(total) FILTER (WHERE created_at::date = CURRENT_DATE), 0) AS ventas_hoy,
                       COALESCE(SUM(total), 0) AS ventas_totales
                FROM pedidos
            ), pedidos AS (
                SELECT COUNT(*) FILTER (WHERE estado = 'pendiente')::int AS pedidos_pendientes,
                       COUNT(*) FILTER (WHERE estado = 'entregado')::int AS pedidos_entregados
                FROM pedidos
            ), usuarios AS (
                SELECT COUNT(*) FILTER (WHERE created_at::date = CURRENT_DATE)::int AS nuevos_clientes
                FROM usuarios
            ), top_producto AS (
                SELECT p.nombre AS producto_mas_vendido,
                       COALESCE(SUM(dp.cantidad),0)::int AS producto_mas_vendido_cantidad
                FROM productos p
                LEFT JOIN detalle_pedidos dp ON p.id_producto = dp.id_producto
                GROUP BY p.id_producto, p.nombre
                ORDER BY producto_mas_vendido_cantidad DESC
                LIMIT 1
            )
            SELECT v.ventas_hoy, v.ventas_totales,
                   pe.pedidos_pendientes, pe.pedidos_entregados,
                   u.nuevos_clientes,
                   COALESCE(tp.producto_mas_vendido,'N/D') AS producto_mas_vendido,
                   COALESCE(tp.producto_mas_vendido_cantidad,0) AS producto_mas_vendido_cantidad
            FROM ventas v, pedidos pe, usuarios u
            LEFT JOIN top_producto tp ON TRUE
        """;

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(inlineSql);
             ResultSet rs = stmt.executeQuery()) {
            if (rs.next()) return mapStats(rs);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al consultar estadísticas del dashboard", e);
        }
        Map<String, Object> empty = new HashMap<>();
        empty.put("ventas_hoy", 0);
        empty.put("ventas_totales", 0);
        empty.put("pedidos_pendientes", 0);
        empty.put("pedidos_entregados", 0);
        empty.put("nuevos_clientes", 0);
        empty.put("producto_mas_vendido", "N/D");
        empty.put("producto_mas_vendido_cantidad", 0);
        return empty;
    }

    public Map<String, Object> obtenerEstadisticasDelivery(int idDelivery) {
        final String sql = """
            SELECT
              COUNT(*) FILTER (WHERE estado='entregado' AND updated_at::date=CURRENT_DATE)::int AS pedidos_completados_hoy,
              COALESCE(SUM(total) FILTER (WHERE estado='entregado' AND updated_at::date=CURRENT_DATE),0) AS total_generado_hoy,
              AVG(EXTRACT(EPOCH FROM (updated_at - created_at))/60.0) FILTER (WHERE estado='entregado'
                    AND updated_at IS NOT NULL AND created_at IS NOT NULL) AS tiempo_promedio_min
            FROM pedidos
            WHERE id_delivery = ?
        """;
        try (Connection c = Database.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idDelivery);
            try (ResultSet rs = ps.executeQuery()) {
                Map<String, Object> out = new HashMap<>();
                out.put("pedidos_completados_hoy", 0);
                out.put("total_generado_hoy", 0.0);
                out.put("tiempo_promedio_min", 0.0);
                if (rs.next()) {
                    out.put("pedidos_completados_hoy", rs.getInt("pedidos_completados_hoy"));
                    out.put("total_generado_hoy", rs.getDouble("total_generado_hoy"));
                    double t = rs.getDouble("tiempo_promedio_min");
                    if (!rs.wasNull()) out.put("tiempo_promedio_min", t);
                }
                return out;
            }
        } catch (SQLException e) {
            throw new ApiException(500, "Error obteniendo estadísticas del delivery", e);
        }
    }

    private Map<String, Object> mapStats(ResultSet rs) throws SQLException {
        Map<String, Object> stats = new HashMap<>();
        stats.put("ventas_hoy", rs.getBigDecimal("ventas_hoy"));
        stats.put("ventas_totales", rs.getBigDecimal("ventas_totales"));
        stats.put("pedidos_pendientes", rs.getInt("pedidos_pendientes"));
        stats.put("pedidos_entregados", rs.getInt("pedidos_entregados"));
        stats.put("nuevos_clientes", rs.getInt("nuevos_clientes"));
        stats.put("producto_mas_vendido", rs.getString("producto_mas_vendido"));
        stats.put("producto_mas_vendido_cantidad", rs.getInt("producto_mas_vendido_cantidad"));
        return stats;
    }
}
