-- =================================================================
-- ESQUEMA ÚNICO Y CONSOLIDADO PARA LA BASE DE DATOS DELIVERY
-- Este archivo reemplaza a `database_alter.sql` y `Base de datos correcta.sql`.
-- =================================================================

BEGIN;

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =================================================================
-- TABLAS PRINCIPALES
-- =================================================================

CREATE TABLE IF NOT EXISTS public.usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) NOT NULL UNIQUE,
    contrasena TEXT NOT NULL,
    telefono VARCHAR(20),
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('cliente', 'delivery', 'admin', 'soporte')),
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMPTZ DEFAULT NOW(),
    latitud_actual DECIMAL(10, 6),
    longitud_actual DECIMAL(10, 6)
);

CREATE TABLE IF NOT EXISTS public.ubicaciones (
    id_ubicacion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE,
    latitud DOUBLE PRECISION NOT NULL CHECK (latitud >= -90 AND latitud <= 90),
    longitud DOUBLE PRECISION NOT NULL CHECK (longitud >= -180 AND longitud <= 180),
    direccion TEXT,
    descripcion TEXT,
    activa BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMPTZ DEFAULT NOW()
);

-- Añadir restricción única para la ubicación en vivo del repartidor
ALTER TABLE public.ubicaciones
    ADD CONSTRAINT uq_live_tracking_one_per_user UNIQUE (id_usuario, descripcion)
    WHERE (descripcion = 'LIVE_TRACKING');

CREATE TABLE IF NOT EXISTS public.productos (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10, 2) NOT NULL CHECK (precio >= 0),
    imagen_url VARCHAR(500),
    categoria VARCHAR(100),
    disponible BOOLEAN DEFAULT TRUE,
    proveedor VARCHAR(100),
    codigo_barras VARCHAR(50),
    descuento NUMERIC(5, 2) DEFAULT 0,
    destacado BOOLEAN DEFAULT FALSE,
    unidad_medida VARCHAR(20),
    fecha_expiracion DATE,
    costo NUMERIC(10, 2),
    ganancia NUMERIC(10, 2),
    rating NUMERIC(3, 2) DEFAULT 0,
    etiquetas TEXT[],
    ultima_compra TIMESTAMPTZ,
    ultima_actualizacion TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_productos_nombre ON productos (nombre);

CREATE TABLE IF NOT EXISTS public.pedidos (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INTEGER NOT NULL REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE,
    id_delivery INTEGER REFERENCES public.usuarios(id_usuario) ON DELETE SET NULL,
    id_ubicacion INTEGER REFERENCES public.ubicaciones(id_ubicacion) ON DELETE SET NULL,
    estado VARCHAR(50) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'en preparacion', 'en camino', 'entregado', 'cancelado')),
    total NUMERIC(10, 2) NOT NULL DEFAULT 0,
    direccion_entrega TEXT,
    metodo_pago VARCHAR(50) NOT NULL,
    notas TEXT,
    coordenadas_entrega VARCHAR(255),
    fecha_pedido TIMESTAMPTZ DEFAULT NOW(),
    fecha_entrega TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.detalle_pedidos (
    id_detalle SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES public.pedidos(id_pedido) ON DELETE CASCADE,
    id_producto INTEGER NOT NULL REFERENCES public.productos(id_producto),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10, 2) NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tracking_eventos (
    id_evento SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES public.pedidos(id_pedido) ON DELETE CASCADE,
    orden INTEGER NOT NULL DEFAULT 1,
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    descripcion TEXT,
    fecha_evento TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tracking_eventos_pedido
    ON public.tracking_eventos(id_pedido, orden, fecha_evento);

CREATE TABLE IF NOT EXISTS public.recomendaciones (
    id_recomendacion SERIAL PRIMARY KEY,
    id_producto INTEGER NOT NULL REFERENCES public.productos(id_producto) ON DELETE CASCADE,
    id_usuario INTEGER NOT NULL REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE,
    puntuacion INTEGER NOT NULL CHECK (puntuacion >= 1 AND puntuacion <= 5),
    comentario TEXT,
    fecha TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_producto, id_usuario)
);

CREATE TABLE IF NOT EXISTS public.chat_conversaciones (
    id_conversacion BIGINT PRIMARY KEY,
    id_pedido INTEGER REFERENCES public.pedidos(id_pedido) ON DELETE SET NULL,
    id_cliente INTEGER REFERENCES public.usuarios(id_usuario) ON DELETE SET NULL,
    id_delivery INTEGER REFERENCES public.usuarios(id_usuario) ON DELETE SET NULL,
    id_admin_soporte INTEGER REFERENCES public.usuarios(id_usuario) ON DELETE SET NULL,
    fecha_creacion TIMESTAMPTZ DEFAULT NOW(),
    activa BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.chat_mensajes (
    id_mensaje BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    id_conversacion BIGINT NOT NULL REFERENCES public.chat_conversaciones(id_conversacion) ON DELETE CASCADE,
    id_remitente INTEGER NOT NULL REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE,
    id_destinatario INTEGER REFERENCES public.usuarios(id_usuario) ON DELETE SET NULL,
    mensaje TEXT NOT NULL,
    fecha_envio TIMESTAMPTZ DEFAULT NOW()
);

-- =================================================================
-- FUNCIONES Y TRIGGERS
-- =================================================================

-- Función para hashear contraseñas con BCrypt
CREATE OR REPLACE FUNCTION public.usuarios_hash_password_bcrypt()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.contrasena IS NOT NULL AND NEW.contrasena !~ '^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$' THEN
        NEW.contrasena := crypt(NEW.contrasena, gen_salt('bf', 12));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para hashear la contraseña antes de insertar o actualizar
DROP TRIGGER IF EXISTS trg_usuarios_hash_password ON public.usuarios;
CREATE TRIGGER trg_usuarios_hash_password
BEFORE INSERT OR UPDATE OF contrasena ON public.usuarios
FOR EACH ROW EXECUTE FUNCTION public.usuarios_hash_password_bcrypt();


-- =================================================================
-- VISTAS PARA DASHBOARDS
-- =================================================================

CREATE OR REPLACE VIEW vw_admin_resumen_diario AS
WITH pedidos_data AS (
    SELECT
        COALESCE(SUM(CASE WHEN estado = 'entregado' AND DATE(fecha_pedido) = CURRENT_DATE THEN total END), 0)::NUMERIC(12,2) AS ventas_hoy,
        COALESCE(SUM(CASE WHEN estado = 'entregado' THEN total END), 0)::NUMERIC(12,2) AS ventas_totales,
        COUNT(*) FILTER (WHERE estado NOT IN ('entregado', 'cancelado')) AS pedidos_pendientes,
        COUNT(*) FILTER (WHERE estado = 'entregado') AS pedidos_entregados
    FROM pedidos
), clientes_data AS (
    SELECT COUNT(*) AS nuevos_clientes
    FROM usuarios
    WHERE rol = 'cliente' AND DATE(fecha_registro) = CURRENT_DATE
)
SELECT
    pd.ventas_hoy,
    pd.ventas_totales,
    pd.pedidos_pendientes,
    pd.pedidos_entregados,
    cd.nuevos_clientes
FROM pedidos_data pd, clientes_data cd;

CREATE OR REPLACE VIEW vw_admin_producto_top AS
SELECT
    pr.id_producto,
    pr.nombre,
    SUM(dp.cantidad)::INTEGER AS unidades_vendidas
FROM detalle_pedidos dp
JOIN productos pr ON pr.id_producto = dp.id_producto
JOIN pedidos p ON p.id_pedido = dp.id_pedido
WHERE p.estado = 'entregado'
GROUP BY pr.id_producto, pr.nombre
ORDER BY unidades_vendidas DESC, pr.nombre
LIMIT 1;

-- =================================================================
-- FUNCIÓN CONSOLIDADA PARA DASHBOARD
-- =================================================================

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

-- =================================================================
-- DATOS INICIALES (SEEDS)
-- =================================================================

-- Insertar usuarios de prueba si no existen
INSERT INTO public.usuarios (nombre, correo, contrasena, rol, telefono)
VALUES
    ('Admin Sistema', 'admin@example.com', 'admin123', 'admin', '0987654324'),
    ('Repartidor Demo', 'delivery@example.com', 'delivery123', 'delivery', '0987654323'),
    ('Cliente Demo', 'cliente@example.com', 'cliente123', 'cliente', '0987654321'),
    ('Asistente Virtual', 'chatbot@system.local', 'chatbot123', 'soporte', '0000000000'),
    ('Negocio XYZ', 'negocio@example.com', 'negocio123', 'negocio', '0999999999'),
    ('Maria Garcia', 'maria@example.com', '123456', 'cliente', '0987654322'),
    ('Carlos Lopez', 'carlos@example.com', '1234567', 'delivery', '0987654323'),
    ('Lucas Gomez', 'lucas@example.com', '1234567', 'soporte', '0911111111')
ON CONFLICT (correo) DO NOTHING;

-- Insertar productos de prueba si no existen
INSERT INTO public.productos (nombre, descripcion, precio, imagen_url, categoria, disponible)
VALUES
    ('Pizza Margarita', 'Pizza tradicional con tomate, mozzarella y albahaca', 12.50, 'https://images.unsplash.com/photo-1548365328-860eee694d7b', 'Pizzas', TRUE),
    ('Hamburguesa Clásica', 'Hamburguesa con carne, lechuga, tomate y queso', 8.99, 'https://images.unsplash.com/photo-1550547660-d9450f859349', 'Hamburguesas', TRUE),
    ('Papas Fritas', 'Papas fritas crujientes listas para compartir', 3.50, 'https://images.unsplash.com/photo-1550450005-4a1bca4de59c', 'Acompañamientos', TRUE)
ON CONFLICT (nombre) DO NOTHING;

-- Registrar el perfil del negocio demo
INSERT INTO public.negocios (id_negocio, nombre_comercial, razon_social, ruc, direccion, telefono, email_contacto, horario)
SELECT id_usuario, 'Negocio XYZ', 'Negocio XYZ S.A.', '1790012345001', 'Av. Libertad y Malecón, Esmeraldas', '0999999999',
       'contacto@negocioxyz.ec', 'L-V 09:00-18:00; S 09:00-14:00'
FROM public.usuarios
WHERE correo = 'negocio@example.com'
ON CONFLICT (id_negocio) DO NOTHING;

-- Vincular productos de ejemplo al negocio cuando exista
UPDATE public.productos
SET proveedor = 'Negocio XYZ', id_negocio = (
    SELECT id_usuario FROM public.usuarios WHERE correo = 'negocio@example.com'
)
WHERE proveedor IS NULL;

-- Ubicaciones predeterminadas para cliente y repartidor demo
WITH cliente AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'maria@example.com' OR correo = 'cliente@example.com' LIMIT 1),
     delivery AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'carlos@example.com' OR correo = 'delivery@example.com' LIMIT 1)
INSERT INTO public.ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa)
VALUES
    ((SELECT id_usuario FROM cliente), 0.989000, -79.653000, 'Av. Quito 999', 'Casa del cliente', TRUE),
    ((SELECT id_usuario FROM delivery), 0.990000, -79.655000, 'Calle Falsa 123', 'Punto de partida', TRUE)
ON CONFLICT DO NOTHING;

-- Ubicación viva del repartidor para los endpoints de tracking
WITH delivery AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'carlos@example.com' OR correo = 'delivery@example.com' LIMIT 1)
INSERT INTO public.ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa)
VALUES ((SELECT id_usuario FROM delivery), 0.970362, -79.652557, 'Base de salida del repartidor', 'LIVE_TRACKING', TRUE)
ON CONFLICT (id_usuario, descripcion)
WHERE (descripcion = 'LIVE_TRACKING')
DO UPDATE SET latitud = EXCLUDED.latitud, longitud = EXCLUDED.longitud, fecha_registro = NOW();

-- Pedido de demostración con detalle para alimentar dashboards
WITH cliente AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'maria@example.com' OR correo = 'cliente@example.com' LIMIT 1),
     delivery AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'carlos@example.com' OR correo = 'delivery@example.com' LIMIT 1),
     ubicacion AS (
        INSERT INTO public.ubicaciones (id_usuario, latitud, longitud, direccion, descripcion, activa)
        SELECT (SELECT id_usuario FROM cliente), 0.989, -79.653, 'Av. Quito 999', 'Entrega principal', TRUE
        RETURNING id_ubicacion
     ),
     pedido AS (
        INSERT INTO public.pedidos (id_cliente, id_delivery, id_ubicacion, estado, total, metodo_pago, direccion_entrega, fecha_entrega)
        SELECT (SELECT id_usuario FROM cliente), (SELECT id_usuario FROM delivery), (SELECT id_ubicacion FROM ubicacion),
               'en camino', 18.00, 'tarjeta', 'Av. Quito 999', NOW()
        RETURNING id_pedido
     )
INSERT INTO public.detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT (SELECT id_pedido FROM pedido), id_producto, 1, precio, precio
FROM public.productos
ORDER BY id_producto
LIMIT 2;

-- Ruta simulada asociada al pedido demo
WITH pedido_actual AS (
  SELECT id_pedido FROM public.pedidos
  WHERE estado IN ('en camino','pendiente')
  ORDER BY id_pedido DESC
  LIMIT 1
), puntos AS (
  SELECT 1 AS orden, 0.970362::DOUBLE PRECISION AS latitud, -79.652557::DOUBLE PRECISION AS longitud,
         'Inicio en restaurante'::TEXT AS descripcion, NOW() - INTERVAL '15 minutes' AS fecha_evento
  UNION ALL SELECT 2, 0.972900, -79.654900, 'Retiro del pedido', NOW() - INTERVAL '12 minutes'
  UNION ALL SELECT 3, 0.978120, -79.655900, 'En camino por Av. Libertad', NOW() - INTERVAL '9 minutes'
  UNION ALL SELECT 4, 0.983438, -79.655182, 'Cruce principal', NOW() - INTERVAL '6 minutes'
  UNION ALL SELECT 5, 0.984854, -79.657457, 'Cerca del destino', NOW() - INTERVAL '3 minutes'
  UNION ALL SELECT 6, 0.988033, -79.659094, 'Entrega en puerta', NOW()
)
INSERT INTO public.tracking_eventos (id_pedido, orden, latitud, longitud, descripcion, fecha_evento)
SELECT pa.id_pedido, pt.orden, pt.latitud, pt.longitud, pt.descripcion, pt.fecha_evento
FROM pedido_actual pa
JOIN puntos pt ON TRUE;

-- Conversación pre-cargada para el asistente virtual
WITH cliente AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'maria@example.com' OR correo = 'cliente@example.com' LIMIT 1),
     bot AS (SELECT id_usuario FROM public.usuarios WHERE correo = 'chatbot@system.local' LIMIT 1),
     conversacion AS (
       INSERT INTO public.chat_conversaciones (id_conversacion, id_cliente, activa)
       VALUES (1000001, (SELECT id_usuario FROM cliente), TRUE)
       ON CONFLICT (id_conversacion) DO UPDATE SET activa = TRUE
       RETURNING id_conversacion
     ),
     conv_id AS (
       SELECT id_conversacion FROM conversacion
       UNION
       SELECT 1000001 WHERE NOT EXISTS (SELECT 1 FROM conversacion)
     )
INSERT INTO public.chat_mensajes (id_conversacion, id_remitente, id_destinatario, mensaje, fecha_envio)
VALUES
  ((SELECT id_conversacion FROM conv_id), (SELECT id_usuario FROM cliente), (SELECT id_usuario FROM bot),
   'Hola, ¿podrías confirmar mi entrega?', NOW() - INTERVAL '5 minutes'),
  ((SELECT id_conversacion FROM conv_id), (SELECT id_usuario FROM bot), (SELECT id_usuario FROM cliente),
   '¡Hola! Tu pedido está en ruta y llegará en menos de 15 minutos.', NOW() - INTERVAL '4 minutes'),
  ((SELECT id_conversacion FROM conv_id), (SELECT id_usuario FROM cliente), (SELECT id_usuario FROM bot),
   'Gracias, estaré pendiente.', NOW() - INTERVAL '3 minutes');


-- =================================================================
-- MIGRACIÓN DE DATOS (SI ES NECESARIO)
-- =================================================================

-- Migrar datos de la tabla `mensajes` (antigua) a `chat_mensajes` (nueva)
-- Esto es un ejemplo y debe adaptarse a la lógica de negocio.
-- Asumimos que cada pedido tenía su propio "chat".

-- 1. Crear conversaciones a partir de pedidos con mensajes
INSERT INTO chat_conversaciones (id_conversacion, id_pedido, id_cliente, id_delivery)
SELECT
    m.id_pedido AS id_conversacion,
    m.id_pedido,
    p.id_cliente,
    p.id_delivery
FROM (SELECT DISTINCT id_pedido FROM public.mensajes) m
JOIN public.pedidos p ON m.id_pedido = p.id_pedido
ON CONFLICT (id_conversacion) DO NOTHING;

-- 2. Migrar los mensajes
INSERT INTO chat_mensajes (id_conversacion, id_remitente, id_destinatario, mensaje, fecha_envio)
SELECT
    m.id_pedido, -- Usamos el id_pedido como id_conversacion
    m.id_remitente,
    m.id_destinatario,
    m.mensaje,
    m.fecha_envio
FROM public.mensajes m
WHERE EXISTS (SELECT 1 FROM chat_conversaciones cc WHERE cc.id_conversacion = m.id_pedido);

-- 3. (Opcional) Eliminar la tabla `mensajes` antigua si ya no se necesita
-- DROP TABLE IF EXISTS public.mensajes;


-- =================================================================
-- ÍNDICES ADICIONALES PARA MEJORAR RENDIMIENTO
-- =================================================================

CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON public.pedidos(id_cliente);
CREATE INDEX IF NOT EXISTS idx_pedidos_delivery ON public.pedidos(id_delivery);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado ON public.pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_ubicaciones_usuario ON public.ubicaciones(id_usuario);
CREATE INDEX IF NOT EXISTS idx_chat_mensajes_conversacion ON public.chat_mensajes(id_conversacion);
CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_cliente ON public.chat_conversaciones(id_cliente);
CREATE INDEX IF NOT EXISTS idx_chat_conversaciones_delivery ON public.chat_conversaciones(id_delivery);

COMMIT;
