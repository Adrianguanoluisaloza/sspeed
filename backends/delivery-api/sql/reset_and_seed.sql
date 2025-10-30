-- PostgreSQL reset & seed for Delivery API
-- Usage:
--   psql -h localhost -U postgres -d sspeed -f sspeed/backends/delivery-api/sql/reset_and_seed.sql
-- Adjust database/user as needed.

BEGIN;

-- Vistas y funciones dependientes
DROP VIEW IF EXISTS vw_admin_producto_top CASCADE;
DROP VIEW IF EXISTS vw_admin_resumen_diario CASCADE;
DROP VIEW IF EXISTS vw_delivery_stats CASCADE;
DROP FUNCTION IF EXISTS fn_admin_dashboard() CASCADE;

-- Drop existing schema (safe order via CASCADE)
DROP TABLE IF EXISTS chat_mensajes CASCADE;
DROP TABLE IF EXISTS chat_conversaciones CASCADE;
DROP TABLE IF EXISTS detalle_pedidos CASCADE;
DROP TABLE IF EXISTS pedidos CASCADE;
DROP TABLE IF EXISTS ubicaciones CASCADE;
DROP TABLE IF EXISTS recomendaciones CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS negocios CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;

-- Usuarios
CREATE TABLE usuarios (
  id_usuario       SERIAL PRIMARY KEY,
  nombre           VARCHAR(120) NOT NULL,
  correo           VARCHAR(160) NOT NULL UNIQUE,
  contrasena       VARCHAR(200) NOT NULL,
  telefono         VARCHAR(30),
  rol              VARCHAR(30) NOT NULL CHECK (rol IN ('cliente','repartidor','delivery','soporte','admin','negocio')),
  activo           BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Tabla de negocios (perfil de comercio) vinculada a un usuario propietario
CREATE TABLE negocios (
  id_negocio       INT PRIMARY KEY REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  nombre_comercial VARCHAR(160) NOT NULL,
  razon_social     VARCHAR(160),
  ruc              VARCHAR(20),
  direccion        TEXT,
  telefono         VARCHAR(30),
  email_contacto   VARCHAR(160),
  logo_url         VARCHAR(500),
  latitud          DOUBLE PRECISION,
  longitud         DOUBLE PRECISION,
  horario          TEXT,
  activo           BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW()
);
-- Productos
CREATE TABLE productos (
  id_producto      SERIAL PRIMARY KEY,
  nombre           VARCHAR(200) NOT NULL,
  descripcion      TEXT,
  categoria        VARCHAR(80),
  precio           NUMERIC(10,2) NOT NULL DEFAULT 0,
  imagen_url       VARCHAR(500),
  disponible       BOOLEAN DEFAULT TRUE,
  proveedor        VARCHAR(100),
  id_negocio       INT REFERENCES negocios(id_negocio)
);

-- Recomendaciones
CREATE TABLE recomendaciones (
  id_recomendacion SERIAL PRIMARY KEY,
  id_producto      INT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
  id_usuario       INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  puntuacion       INT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
  comentario       TEXT,
  fecha            TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT recomendaciones_unique UNIQUE (id_producto, id_usuario)
);

-- Ubicaciones
CREATE TABLE ubicaciones (
  id_ubicacion     SERIAL PRIMARY KEY,
  id_usuario       INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  latitud          DOUBLE PRECISION NOT NULL,
  longitud         DOUBLE PRECISION NOT NULL,
  direccion        TEXT NOT NULL,
  descripcion      TEXT,
  activa           BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Pedidos
CREATE TABLE pedidos (
  id_pedido        SERIAL PRIMARY KEY,
  id_cliente       INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
  id_delivery      INT REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
  id_ubicacion     INT NOT NULL REFERENCES ubicaciones(id_ubicacion) ON DELETE RESTRICT,
  estado           VARCHAR(30) NOT NULL DEFAULT 'pendiente',
  total            NUMERIC(10,2) NOT NULL DEFAULT 0,
  metodo_pago      VARCHAR(30) NOT NULL DEFAULT 'efectivo',
  direccion_entrega TEXT,
  fecha_pedido     TIMESTAMP NOT NULL DEFAULT NOW(),
  fecha_entrega    TIMESTAMP NULL,
  notas            TEXT,
  coordenadas_entrega TEXT
);

-- Detalle Pedido
CREATE TABLE detalle_pedidos (
  id_detalle       SERIAL PRIMARY KEY,
  id_pedido        INT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
  id_producto      INT NOT NULL REFERENCES productos(id_producto) ON DELETE RESTRICT,
  cantidad         INT NOT NULL CHECK (cantidad > 0),
  precio_unitario  NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
  subtotal         NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0)
);

-- Chat: Conversaciones y Mensajes
CREATE TABLE chat_conversaciones (
  id_conversacion  BIGINT PRIMARY KEY,
  id_pedido        INT,
  id_cliente       INT,
  id_delivery      INT,
  id_admin_soporte INT,
  fecha_creacion   TIMESTAMP NOT NULL DEFAULT NOW(),
  activa           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_cliente
  ON chat_conversaciones(id_cliente, fecha_creacion DESC);

CREATE TABLE chat_mensajes (
  id_mensaje       SERIAL PRIMARY KEY,
  id_conversacion  BIGINT NOT NULL REFERENCES chat_conversaciones(id_conversacion) ON DELETE CASCADE,
  id_remitente     INT REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  id_destinatario  INT REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
  mensaje          TEXT NOT NULL,
  fecha_envio      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_mensajes_conversacion
  ON chat_mensajes(id_conversacion, fecha_envio);

-- Seeds: Usuarios (contrasenas en texto plano para permitir auto-hash en primer login)
INSERT INTO usuarios (nombre, correo, contrasena, telefono, rol)
VALUES
  ('Maria Garcia',  'maria@example.com',  '123456',   '0987654322', 'cliente'),
  ('Carlos Lopez',  'carlos@example.com', '1234567',  '0987654323', 'delivery'),
  ('Lucas Gomez',   'lucas@example.com',  '1234567',  '0911111111', 'soporte'),
  ('Admin Sistema', 'admin@example.com',  'admin123', '0000000000', 'admin'),
  ('Negocio XYZ',   'negocio@example.com','negocio123','0999999999', 'negocio'),
  ('Asistente Virtual','chatbot@system.local','chatbot123','0000000000','soporte')
ON CONFLICT (correo) DO NOTHING;
-- Perfil del Negocio XYZ
INSERT INTO negocios (id_negocio, nombre_comercial, razon_social, ruc, direccion, telefono, email_contacto, logo_url, latitud, longitud, horario)
SELECT id_usuario, 'Negocio XYZ', 'Negocio XYZ S.A.', '1790012345001', 'Av. Libertad y Malecon, Esmeraldas', '0999999999', 'contacto@negocioxyz.ec', NULL, NULL, NULL, 'L-V 09:00-18:00; S 09:00-14:00'
FROM usuarios WHERE correo='negocio@example.com'
ON CONFLICT (id_negocio) DO NOTHING;

-- Seeds: Productos
-- Referencias de negocio
WITH n AS (SELECT id_negocio FROM negocios WHERE id_negocio = (SELECT id_usuario FROM usuarios WHERE correo='negocio@example.com'))
INSERT INTO productos (nombre, descripcion, categoria, precio, imagen_url, disponible, proveedor, id_negocio) VALUES
  ('Hamburguesa Clasica','Pan, carne, lechuga y tomate','Comida', 5.50, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Pizza Margarita','Queso y tomate','Comida', 8.00, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Ensalada Cesar','Lechuga, pollo, salsa cesar','Comida', 4.75, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Jugo de Naranja','Natural recien exprimido','Bebidas', 2.50, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Limonada','Refrescante limonada casera','Bebidas', 2.00, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Papas Fritas','Crocantes, porcion individual','Acompanantes', 1.75, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Alitas BBQ','Media docena con salsa BBQ','Comida', 6.50, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n)),
  ('Empanadas de Queso','Paquete de 3 unidades','Comida', 3.00, NULL, TRUE, 'Negocio XYZ', (SELECT id_negocio FROM n))
ON CONFLICT DO NOTHING;

-- Seeds: Recomendaciones iniciales para popular 'destacadas'
WITH 
  u_maria AS (SELECT id_usuario AS id FROM usuarios WHERE correo='maria@example.com'),
  u_carlos AS (SELECT id_usuario AS id FROM usuarios WHERE correo='carlos@example.com'),
  pr_hamb AS (SELECT id_producto AS id FROM productos WHERE nombre='Hamburguesa Clasica' LIMIT 1),
  pr_pizza AS (SELECT id_producto AS id FROM productos WHERE nombre='Pizza Margarita' LIMIT 1),
  pr_papas AS (SELECT id_producto AS id FROM productos WHERE nombre='Papas Fritas' LIMIT 1)
INSERT INTO recomendaciones (id_producto, id_usuario, puntuacion, comentario)
VALUES
  ((SELECT id FROM pr_hamb), (SELECT id FROM u_maria), 5, 'Muy buena, la recomiendo!'),
  ((SELECT id FROM pr_pizza), (SELECT id FROM u_maria), 4, 'Sabrosa y fresca.'),
  ((SELECT id FROM pr_papas), (SELECT id FROM u_carlos), 5, 'Crocantes y perfectas para acompanar.'),
  ((SELECT id FROM pr_hamb), (SELECT id FROM u_carlos), 4, 'Rapida entrega y buen sabor.')
ON CONFLICT DO NOTHING;

-- Seeds: Ubicaciones para cliente y delivery
WITH c AS (SELECT id_usuario FROM usuarios WHERE correo='maria@example.com'),
     d AS (SELECT id_usuario FROM usuarios WHERE correo='carlos@example.com')
INSERT INTO ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa)
SELECT (SELECT id_usuario FROM c), 0.988, -79.652, 'Av. Quito 999', 'Casa de Maria', TRUE
UNION ALL
SELECT (SELECT id_usuario FROM d), 0.990, -79.655, 'Calle Falsa 123', 'Posicion de Carlos', TRUE;

-- Ubicaciones reales de Esmeraldas para delivery (tracking)
WITH d AS (SELECT id_usuario FROM usuarios WHERE correo='carlos@example.com')
INSERT INTO ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa) VALUES
((SELECT id_usuario FROM d), 0.970362, -79.652557, 'Punto 1', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.970524, -79.655029, 'Punto 2', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.976980, -79.654840, 'Punto 3', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.988033, -79.659094, 'Punto 4', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.988458, -79.659789, 'Punto 5', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.983438, -79.655182, 'Punto 6', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.984854, -79.657457, 'Punto 7', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.978510, -79.658961, 'Punto 8', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.977286, -79.660390, 'Punto 9', 'LIVE_TRACKING', TRUE),
((SELECT id_usuario FROM d), 0.959480, -79.657965, 'Punto 10', 'LIVE_TRACKING', TRUE);

-- Seeds: Pedido de prueba con detalle (cliente -> delivery)
WITH c AS (SELECT id_usuario FROM usuarios WHERE correo='maria@example.com'),
     d AS (SELECT id_usuario FROM usuarios WHERE correo='carlos@example.com'),
     u AS (
       INSERT INTO ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa)
       SELECT (SELECT id_usuario FROM c), 0.989, -79.653, 'Av. Quito 999', 'Entrega principal', TRUE
       RETURNING id_ubicacion
     ),
     p AS (
       INSERT INTO pedidos (id_cliente, id_delivery, id_ubicacion, estado, total, metodo_pago, direccion_entrega, fecha_entrega)
       SELECT (SELECT id_usuario FROM c), (SELECT id_usuario FROM d), (SELECT id_ubicacion FROM u), 'en camino', 12.00, 'tarjeta', 'Av. Quito 999', NOW()
       RETURNING id_pedido
     )
INSERT INTO detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT (SELECT id_pedido FROM p), id_producto, 1, precio, precio FROM productos LIMIT 1;

-- Seeds: Conversacion Bot para cliente
WITH c AS (SELECT id_usuario FROM usuarios WHERE correo='maria@example.com')
INSERT INTO chat_conversaciones (id_conversacion, id_pedido, id_cliente, id_delivery, id_admin_soporte, activa)
VALUES (EXTRACT(EPOCH FROM NOW())::BIGINT * 1000 + 1, NULL, (SELECT id_usuario FROM c), NULL, NULL, TRUE)
ON CONFLICT DO NOTHING;

-- Indexes (performance)
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(id_cliente);
CREATE INDEX IF NOT EXISTS idx_pedidos_delivery ON pedidos(id_delivery);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado ON pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_ubicaciones_usuario ON ubicaciones(id_usuario);
CREATE INDEX IF NOT EXISTS idx_ubicaciones_usuario_fecha ON ubicaciones(id_usuario, fecha_registro DESC);
CREATE INDEX IF NOT EXISTS idx_productos_id_negocio ON productos(id_negocio);
CREATE INDEX IF NOT EXISTS idx_detalle_pedidos_pedido ON detalle_pedidos(id_pedido);
CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_delivery ON chat_conversaciones(id_delivery, fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_soporte ON chat_conversaciones(id_admin_soporte, fecha_creacion DESC);

-- Vistas para dashboards y métricas
CREATE OR REPLACE VIEW vw_delivery_stats AS
SELECT
    u.id_usuario                           AS id_delivery,
    u.nombre                               AS nombre_delivery,
    COUNT(*) FILTER (
        WHERE p.estado = 'entregado'
          AND p.fecha_entrega::date = CURRENT_DATE
    )::INT                                 AS pedidos_completados_hoy,
    COALESCE(SUM(p.total) FILTER (
        WHERE p.estado = 'entregado'
          AND p.fecha_entrega::date = CURRENT_DATE
    ), 0)::NUMERIC(12,2)                   AS total_generado_hoy,
    AVG(EXTRACT(EPOCH FROM (p.fecha_entrega - p.fecha_pedido))/60.0) FILTER (
        WHERE p.estado = 'entregado'
          AND p.fecha_entrega IS NOT NULL
          AND p.fecha_pedido IS NOT NULL
    )                                      AS tiempo_promedio_min
FROM usuarios u
LEFT JOIN pedidos p ON p.id_delivery = u.id_usuario
WHERE u.rol IN ('repartidor','delivery')
GROUP BY u.id_usuario, u.nombre;

CREATE OR REPLACE VIEW vw_admin_resumen_diario AS
SELECT
    CURRENT_DATE                                                   AS fecha_reporte,
    COALESCE(SUM(p.total) FILTER (WHERE p.fecha_pedido::date = CURRENT_DATE), 0)::NUMERIC(12,2) AS ventas_hoy,
    COALESCE(SUM(p.total), 0)::NUMERIC(12,2)                       AS ventas_totales,
    COUNT(*) FILTER (WHERE p.estado = 'pendiente')::INT            AS pedidos_pendientes,
    COUNT(*) FILTER (WHERE p.estado = 'entregado')::INT            AS pedidos_entregados,
    COUNT(*) FILTER (WHERE p.fecha_pedido::date = CURRENT_DATE)::INT AS pedidos_hoy
FROM pedidos p;

CREATE OR REPLACE VIEW vw_admin_producto_top AS
SELECT id_producto, nombre, total_vendido
FROM (
    SELECT
        p.id_producto,
        p.nombre,
        COALESCE(SUM(dp.cantidad), 0)::INT AS total_vendido,
        ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(dp.cantidad),0) DESC, p.nombre) AS rn
    FROM productos p
    LEFT JOIN detalle_pedidos dp ON dp.id_producto = p.id_producto
    GROUP BY p.id_producto, p.nombre
) t
WHERE rn = 1;

CREATE OR REPLACE FUNCTION fn_admin_dashboard()
RETURNS TABLE (
    ventas_hoy NUMERIC,
    ventas_totales NUMERIC,
    pedidos_pendientes INT,
    pedidos_entregados INT,
    nuevos_clientes INT,
    producto_mas_vendido TEXT,
    producto_mas_vendido_cantidad INT
)
LANGUAGE sql
AS $$
    WITH ventas AS (
        SELECT
            COALESCE(SUM(total) FILTER (WHERE fecha_pedido::date = CURRENT_DATE), 0)::NUMERIC(12,2) AS ventas_hoy,
            COALESCE(SUM(total), 0)::NUMERIC(12,2) AS ventas_totales
        FROM pedidos
    ), pedidos_cte AS (
        SELECT
            COUNT(*) FILTER (WHERE estado = 'pendiente')::INT AS pedidos_pendientes,
            COUNT(*) FILTER (WHERE estado = 'entregado')::INT AS pedidos_entregados
        FROM pedidos
    ), usuarios_cte AS (
        SELECT
            COUNT(*) FILTER (WHERE fecha_registro::date = CURRENT_DATE)::INT AS nuevos_clientes
        FROM usuarios
    ), top_producto AS (
        SELECT
            COALESCE(p.nombre, 'N/D') AS producto_mas_vendido,
            COALESCE(SUM(dp.cantidad), 0)::INT AS producto_mas_vendido_cantidad
        FROM productos p
        LEFT JOIN detalle_pedidos dp ON dp.id_producto = p.id_producto
        GROUP BY p.id_producto, p.nombre
        ORDER BY SUM(dp.cantidad) DESC NULLS LAST, p.nombre
        LIMIT 1
    )
    SELECT
        v.ventas_hoy,
        v.ventas_totales,
        p.pedidos_pendientes,
        p.pedidos_entregados,
        u.nuevos_clientes,
        COALESCE(tp.producto_mas_vendido, 'N/D') AS producto_mas_vendido,
        COALESCE(tp.producto_mas_vendido_cantidad, 0) AS producto_mas_vendido_cantidad
    FROM ventas v
    CROSS JOIN pedidos_cte p
    CROSS JOIN usuarios_cte u
    LEFT JOIN top_producto tp ON TRUE;
$$;

COMMIT;
