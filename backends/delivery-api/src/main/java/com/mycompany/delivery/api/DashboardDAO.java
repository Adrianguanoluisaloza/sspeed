package com.mycompany.delivery.api;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.util.ApiException;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

/**
 * Clase para manejar las consultas de estadísticas del Dashboard.
 */
public class DashboardDAO {

    /**
     * Obtiene las estadísticas principales del dashboard del admin usando
     * la función SQL fn_admin_dashboard() para consolidar toda la lógica en la base.
     */
    public Map<String, Object> getStats() {
        String sql = "SELECT * FROM fn_admin_dashboard()";
        Map<String, Object> stats = new HashMap<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            if (rs.next()) {
                stats.put("ventas_hoy", rs.getBigDecimal("ventas_hoy"));
                stats.put("ventas_totales", rs.getBigDecimal("ventas_totales"));
                stats.put("pedidos_pendientes", rs.getInt("pedidos_pendientes"));
                stats.put("pedidos_entregados", rs.getInt("pedidos_entregados"));
                stats.put("nuevos_clientes", rs.getInt("nuevos_clientes"));
                stats.put("producto_mas_vendido", rs.getString("producto_mas_vendido"));
                stats.put("producto_mas_vendido_cantidad", rs.getInt("producto_mas_vendido_cantidad"));
            }

        } catch (SQLException e) {
            e.printStackTrace();
            throw new ApiException(500, "Error al consultar estadísticas del dashboard", e);
        }

        stats.put("success", true);
        return stats;
    }
}
