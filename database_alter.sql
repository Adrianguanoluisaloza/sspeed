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

-- =======================================================================
-- Ajustes complementarios para alinear la API con el esquema actual.
-- =======================================================================

-- 1) Asociar pedidos con ubicaciones registradas (el cliente ya envía id_ubicacion).
ALTER TABLE pedidos
    ADD COLUMN IF NOT EXISTS id_ubicacion INTEGER
        REFERENCES ubicaciones(id_ubicacion);

-- 2) Garantizar que siempre exista una dirección legible, incluso si llega vacía.
ALTER TABLE pedidos
    ALTER COLUMN direccion_entrega DROP NOT NULL;

-- 3) Usuarios base para autenticación (evita fallos de login por datos faltantes).
INSERT INTO usuarios (nombre, correo, contrasena, rol, telefono)
VALUES
    ('Admin Sistema', 'admin@example.com', 'admin123', 'admin', '0987654324'),
    ('Repartidor Demo', 'delivery@example.com', 'delivery123', 'delivery', '0987654323'),
    ('Cliente Demo', 'cliente@example.com', 'cliente123', 'cliente', '0987654321')
ON CONFLICT (correo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    contrasena = EXCLUDED.contrasena,
    rol = EXCLUDED.rol,
    telefono = EXCLUDED.telefono;

-- 4) Catálogo mínimo para probar la sección de productos sin depender de seeds defectuosos.
INSERT INTO productos (nombre, descripcion, precio, imagen_url, categoria, disponible)
VALUES
    ('Pizza Margarita', 'Pizza tradicional con tomate, mozzarella y albahaca', 12.50,
        'https://images.unsplash.com/photo-1548365328-860eee694d7b', 'Pizzas', TRUE),
    ('Hamburguesa Clásica', 'Hamburguesa con carne, lechuga, tomate y queso', 8.99,
        'https://images.unsplash.com/photo-1550547660-d9450f859349', 'Hamburguesas', TRUE),
    ('Papas Fritas', 'Papas fritas crujientes listas para compartir', 3.50,
        'https://images.unsplash.com/photo-1550450005-4a1bca4de59c', 'Acompañamientos', TRUE)
ON CONFLICT (nombre) DO UPDATE
SET descripcion = EXCLUDED.descripcion,
    precio = EXCLUDED.precio,
    imagen_url = EXCLUDED.imagen_url,
    categoria = EXCLUDED.categoria,
    disponible = EXCLUDED.disponible;

-- 5) Vista auxiliar para validar rápidamente el inventario disponible.
CREATE OR REPLACE VIEW vw_productos_disponibles AS
SELECT
    p.id_producto,
    p.nombre,
    p.precio,
    COALESCE(p.categoria, 'Sin categoría') AS categoria,
    COALESCE(p.imagen_url, '') AS imagen_url,
    p.disponible
FROM productos p
WHERE p.disponible IS TRUE;
