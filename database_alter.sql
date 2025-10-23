-- Script auxiliar para exponer métricas del panel administrativo.
-- Mantiene compatibilidad con delivery_db_corrr.sql sin modificar sus tablas base.

-- Vista con métricas diarias y acumuladas para el panel de administración.
CREATE OR REPLACE VIEW vw_admin_resumen_diario AS
WITH pedidos_data AS (
    SELECT
        COALESCE(SUM(CASE
            WHEN LOWER(estado) = 'entregado' AND DATE(fecha_pedido) = CURRENT_DATE THEN total
        END), 0)::NUMERIC(12,2) AS ventas_hoy,
        COALESCE(SUM(CASE
            WHEN LOWER(estado) = 'entregado' THEN total
        END), 0)::NUMERIC(12,2) AS ventas_totales,
        COUNT(*) FILTER (WHERE LOWER(estado) NOT IN ('entregado', 'cancelado')) AS pedidos_pendientes,
        COUNT(*) FILTER (WHERE LOWER(estado) = 'entregado') AS pedidos_entregados
    FROM pedidos
), clientes_data AS (
    SELECT COUNT(*) AS nuevos_clientes
    FROM usuarios
    WHERE rol = 'cliente' AND DATE(fecha_registro) = CURRENT_DATE
)
SELECT
    pedidos_data.ventas_hoy,
    pedidos_data.ventas_totales,
    pedidos_data.pedidos_pendientes,
    pedidos_data.pedidos_entregados,
    clientes_data.nuevos_clientes
FROM pedidos_data, clientes_data;

-- Vista con el producto más vendido considerando pedidos entregados.
CREATE OR REPLACE VIEW vw_admin_producto_top AS
SELECT
    pr.id_producto,
    pr.nombre,
    SUM(dp.cantidad) AS unidades_vendidas
FROM detalle_pedidos dp
JOIN productos pr ON pr.id_producto = dp.id_producto
JOIN pedidos p ON p.id_pedido = dp.id_pedido
WHERE LOWER(p.estado) = 'entregado'
GROUP BY pr.id_producto, pr.nombre
ORDER BY unidades_vendidas DESC, pr.nombre
LIMIT 1;

-- Función que empaqueta los datos del dashboard en un único JSON-like resultset.
CREATE OR REPLACE FUNCTION fn_admin_dashboard()
RETURNS TABLE (
    ventas_hoy NUMERIC(12,2),
    ventas_totales NUMERIC(12,2),
    pedidos_pendientes INTEGER,
    pedidos_entregados INTEGER,
    nuevos_clientes INTEGER,
    producto_mas_vendido TEXT,
    producto_mas_vendido_cantidad INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.ventas_hoy,
        r.ventas_totales,
        r.pedidos_pendientes,
        r.pedidos_entregados,
        r.nuevos_clientes,
        COALESCE(pt.nombre, 'Sin datos') AS producto_mas_vendido,
        COALESCE(pt.unidades_vendidas, 0) AS producto_mas_vendido_cantidad
    FROM vw_admin_resumen_diario r
    LEFT JOIN vw_admin_producto_top pt ON TRUE;
END;
$$ LANGUAGE plpgsql;
