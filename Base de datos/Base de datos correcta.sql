-- ========================================
-- BASE DE DATOS DELIVERY_DB (PostgreSQL)
-- ========================================

-- CREAR ROLES BASE (si aplica sistema de roles)
CREATE TABLE roles (
    id_rol SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

-- USUARIOS
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    id_rol INTEGER REFERENCES roles(id_rol),
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) NOT NULL UNIQUE,
    contrasena TEXT NOT NULL,
    rol VARCHAR(30) NOT NULL, -- redundante para compatibilidad
    telefono VARCHAR(20),
    fecha_registro TIMESTAMPTZ DEFAULT NOW()
);

-- PRODUCTOS
CREATE TABLE productos (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10,2) NOT NULL,
    imagen_url TEXT,
    categoria VARCHAR(50),
    disponible BOOLEAN DEFAULT TRUE
);

-- PEDIDOS
CREATE TABLE pedidos (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    id_delivery INTEGER REFERENCES usuarios(id_usuario),
    direccion_entrega TEXT,
    metodo_pago VARCHAR(50),
    estado VARCHAR(30) DEFAULT 'pendiente',
    total NUMERIC(10,2) NOT NULL,
    fecha_pedido TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    id_ubicacion INTEGER REFERENCES ubicaciones(id_ubicacion)
);

-- DETALLE PEDIDOS
CREATE TABLE detalle_pedidos (
    id_detalle SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    id_producto INTEGER NOT NULL REFERENCES productos(id_producto),
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL
);

-- UBICACIONES (cliente o delivery)
CREATE TABLE ubicaciones (
    id_ubicacion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    latitud NUMERIC(10,6) NOT NULL,
    longitud NUMERIC(10,6) NOT NULL,
    direccion TEXT NOT NULL,
    descripcion TEXT,
    activa BOOLEAN DEFAULT TRUE
);

-- RECOMENDACIONES
CREATE TABLE recomendaciones (
    id_recomendacion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    id_producto INTEGER NOT NULL REFERENCES productos(id_producto),
    puntuacion INTEGER CHECK (puntuacion >= 1 AND puntuacion <= 5),
    comentario TEXT,
    fecha TIMESTAMPTZ DEFAULT NOW()
);

-- MENSAJES entre usuario y delivery
CREATE TABLE mensajes (
    id_mensaje SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES pedidos(id_pedido),
    id_remitente INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    mensaje TEXT NOT NULL,
    fecha TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- VISTAS ADMIN
-- ========================================

-- VISTA: RESUMEN DIARIO
CREATE OR REPLACE VIEW vw_admin_resumen_diario AS
WITH pedidos_data AS (
    SELECT
        COALESCE(SUM(CASE WHEN LOWER(estado) = 'entregado' AND DATE(fecha_pedido) = CURRENT_DATE THEN total END), 0)::NUMERIC(12,2) AS ventas_hoy,
        COALESCE(SUM(CASE WHEN LOWER(estado) = 'entregado' THEN total END), 0)::NUMERIC(12,2) AS ventas_totales,
        COUNT(*) FILTER (WHERE LOWER(estado) NOT IN ('entregado', 'cancelado')) AS pedidos_pendientes,
        COUNT(*) FILTER (WHERE LOWER(estado) = 'entregado') AS pedidos_entregados
    FROM pedidos
),
clientes_data AS (
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

-- VISTA: PRODUCTO MÁS VENDIDO
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

-- VISTA: PRODUCTOS DISPONIBLES
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

-- ========================================
-- FUNCIONES
-- ========================================

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

-- ========================================
-- DATOS SEMILLA PARA PRUEBAS
-- ========================================

-- Roles iniciales
INSERT INTO roles (nombre) VALUES ('admin'), ('delivery'), ('cliente')
ON CONFLICT DO NOTHING;

-- Usuarios de prueba
INSERT INTO usuarios (id_rol, nombre, correo, contrasena, rol, telefono)
VALUES
    ((SELECT id_rol FROM roles WHERE nombre='admin'), 'Sistema Admin', 'admin@example.com', 'admin123', 'admin', '0987654324'),
    ((SELECT id_rol FROM roles WHERE nombre='delivery'), 'Demo Repartidor', 'delivery@example.com', 'entrega123', 'delivery', '0987654323'),
    ((SELECT id_rol FROM roles WHERE nombre='cliente'), 'Cliente Demo', 'cliente@example.com', 'cliente123', 'cliente', '0987654321')
ON CONFLICT (correo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    contrasena = EXCLUDED.contrasena,
    rol = EXCLUDED.rol,
    telefono = EXCLUDED.telefono;

-- Productos base
INSERT INTO productos (nombre, descripcion, precio, imagen_url, categoria, disponible)
VALUES
    ('Pizza Margarita', 'Pizza clásica con mozzarella y albahaca', 12.50, 'https://images.unsplash.com/photo-1548365328-860eee694d7b', 'Pizzas', TRUE),
    ('Hamburguesa Clásica', 'Con lechuga, tomate y queso', 8.99, 'https://images.unsplash.com/photo-1550547660-d9450f859349', 'Hamburguesas', TRUE),
    ('Papas Fritas', 'Acompañamiento crocante', 3.50, 'https://images.unsplash.com/photo-1550450005-4a1bca4de59c', 'Acompañamientos', TRUE)
ON CONFLICT (nombre) DO UPDATE
SET descripcion = EXCLUDED.descripcion,
    precio = EXCLUDED.precio,
    imagen_url = EXCLUDED.imagen_url,
    categoria = EXCLUDED.categoria,
    disponible = EXCLUDED.disponible;

