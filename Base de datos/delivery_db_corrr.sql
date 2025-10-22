CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    contrasena VARCHAR(255) NOT NULL,
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('cliente', 'delivery', 'admin')),
    telefono VARCHAR(20),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de productos
CREATE TABLE IF NOT EXISTS productos (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
    imagen_url VARCHAR(500),
    categoria VARCHAR(50),
    disponible BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    id_delivery INTEGER REFERENCES usuarios(id_usuario),
    estado VARCHAR(50) NOT NULL DEFAULT 'pendiente' 
        CHECK (estado IN ('pendiente', 'en preparacion', 'en camino', 'entregado', 'cancelado')),
    total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    direccion_entrega TEXT NOT NULL,
    metodo_pago VARCHAR(50) NOT NULL CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia')),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega TIMESTAMP,
    notas TEXT
);

-- Tabla de detalle de pedidos
CREATE TABLE IF NOT EXISTS detalle_pedidos (
    id_detalle SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    id_producto INTEGER NOT NULL REFERENCES productos(id_producto),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10, 2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0)
);

-- Tabla de ubicaciones
CREATE TABLE IF NOT EXISTS ubicaciones (
    id_ubicacion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    direccion TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activa BOOLEAN DEFAULT TRUE
);

-- Tabla de recomendaciones
CREATE TABLE IF NOT EXISTS recomendaciones (
    id_recomendacion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    id_producto INTEGER NOT NULL REFERENCES productos(id_producto),
    puntuacion INTEGER NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
    comentario TEXT,
    fecha_recomendacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(id_usuario, id_producto)
);

-- Tabla de chat/mensajes
CREATE TABLE IF NOT EXISTS mensajes (
    id_mensaje SERIAL PRIMARY KEY,
    id_remitente INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    id_destinatario INTEGER NOT NULL REFERENCES usuarios(id_usuario),
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    mensaje TEXT NOT NULL,
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    leido BOOLEAN DEFAULT FALSE
);

-- =====================================================
-- ÍNDICES PARA MEJORAR RENDIMIENTO
-- =====================================================

CREATE INDEX idx_pedidos_cliente ON pedidos(id_cliente);
CREATE INDEX idx_pedidos_delivery ON pedidos(id_delivery);
CREATE INDEX idx_pedidos_estado ON pedidos(estado);
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido);

CREATE INDEX idx_detalle_pedido ON detalle_pedidos(id_pedido);
CREATE INDEX idx_detalle_producto ON detalle_pedidos(id_producto);

CREATE INDEX idx_ubicaciones_usuario ON ubicaciones(id_usuario);
CREATE INDEX idx_ubicaciones_activa ON ubicaciones(activa);

CREATE INDEX idx_recomendaciones_usuario ON recomendaciones(id_usuario);
CREATE INDEX idx_recomendaciones_producto ON recomendaciones(id_producto);

CREATE INDEX idx_mensajes_remitente ON mensajes(id_remitente);
CREATE INDEX idx_mensajes_destinatario ON mensajes(id_destinatario);
CREATE INDEX idx_mensajes_pedido ON mensajes(id_pedido);

-- =====================================================
-- DATOS DE EJEMPLO
-- =====================================================

-- Insertar usuarios de ejemplo
INSERT INTO usuarios (nombre, correo, contrasena, rol, telefono) VALUES
('Juan Pérez', 'juan@example.com', 'password123', 'cliente', '0987654321'),
('María García', 'maria@example.com', 'password123', 'cliente', '0987654322'),
('Carlos López', 'carlos@example.com', 'password123', 'delivery', '0987654323'),
('Admin Sistema', 'admin@example.com', 'admin123', 'admin', '0987654324');

-- Insertar productos de ejemplo
INSERT INTO productos (nombre, descripcion, precio, categoria, imagen_url) VALUES
('Pizza Margarita', 'Pizza tradicional con tomate, mozzarella y albahaca', 12.50, 'Pizzas', 'https://example.com/pizza1.jpg'),
('Hamburguesa Clásica', 'Hamburguesa con carne, lechuga, tomate y queso', 8.99, 'Hamburguesas', 'https://example.com/burger1.jpg'),
('Papas Fritas', 'Papas fritas crujientes', 3.50, 'Acompañamientos', 'https://example.com/fries.jpg'),
('Coca Cola 500ml', 'Bebida gaseosa', 1.50, 'Bebidas', 'https://example.com/cola.jpg'),
('Ensalada César', 'Ensalada fresca con pollo y aderezo césar', 7.99, 'Ensaladas', 'https://example.com/salad.jpg'),
('Pasta Carbonara', 'Pasta con salsa carbonara y tocino', 11.50, 'Pastas', 'https://example.com/pasta.jpg'),
('Tacos Mexicanos', 'Set de 3 tacos con carne y vegetales', 9.99, 'Mexicana', 'https://example.com/tacos.jpg'),
('Sushi Roll', 'Set de 8 piezas de sushi', 15.99, 'Japonesa', 'https://example.com/sushi.jpg');

-- Insertar pedidos de ejemplo
INSERT INTO pedidos (id_cliente, id_delivery, estado, total, direccion_entrega, metodo_pago) VALUES
(1, 3, 'en camino', 24.99, 'Calle Principal #123, Esmeraldas', 'efectivo'),
(2, 3, 'entregado', 18.48, 'Av. Libertad #456, Esmeraldas', 'tarjeta'),
(1, NULL, 'pendiente', 12.50, 'Calle Principal #123, Esmeraldas', 'efectivo');

-- Insertar detalle de pedidos
INSERT INTO detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 1, 12.50, 12.50),
(1, 3, 2, 3.50, 7.00),
(1, 4, 2, 1.50, 3.00),
(2, 2, 2, 8.99, 17.98),
(2, 4, 1, 1.50, 1.50),
(3, 1, 1, 12.50, 12.50);

-- Insertar ubicaciones de ejemplo (Esmeraldas, Ecuador)
INSERT INTO ubicaciones (id_usuario, latitud, longitud, direccion) VALUES
(1, 0.9681, -79.6512, 'Calle Principal #123, Esmeraldas'),
(2, 0.9721, -79.6552, 'Av. Libertad #456, Esmeraldas'),
(3, 0.9651, -79.6482, 'Centro de Distribución, Esmeraldas');

-- Insertar recomendaciones de ejemplo
INSERT INTO recomendaciones (id_usuario, id_producto, puntuacion, comentario) VALUES
(1, 1, 5, '¡Excelente pizza! Muy recomendada'),
(1, 2, 4, 'Buena hamburguesa, pero podría mejorar'),
(2, 1, 5, 'La mejor pizza de la ciudad'),
(2, 5, 4, 'Ensalada fresca y deliciosa');

-- Insertar mensajes de ejemplo
INSERT INTO mensajes (id_remitente, id_destinatario, id_pedido, mensaje) VALUES
(1, 3, 1, 'Hola, ¿cuánto falta para que llegue mi pedido?'),
(3, 1, 1, 'Hola, estoy a 5 minutos de tu ubicación'),
(1, 3, 1, 'Perfecto, gracias');

-- =====================================================
-- VISTAS ÚTILES
-- =====================================================

-- Vista de pedidos con información completa
CREATE OR REPLACE VIEW vista_pedidos_completos AS
SELECT 
    p.id_pedido,
    p.fecha_pedido,
    p.estado,
    p.total,
    p.direccion_entrega,
    p.metodo_pago,
    c.nombre AS cliente_nombre,
    c.correo AS cliente_correo,
    c.telefono AS cliente_telefono,
    d.nombre AS delivery_nombre,
    d.telefono AS delivery_telefono
FROM pedidos p
JOIN usuarios c ON p.id_cliente = c.id_usuario
LEFT JOIN usuarios d ON p.id_delivery = d.id_usuario;

-- Vista de productos más vendidos
CREATE OR REPLACE VIEW vista_productos_populares AS
SELECT 
    pr.id_producto,
    pr.nombre,
    pr.precio,
    COUNT(dp.id_detalle) AS veces_pedido,
    SUM(dp.cantidad) AS total_unidades,
    SUM(dp.subtotal) AS ingresos_totales
FROM productos pr
LEFT JOIN detalle_pedidos dp ON pr.id_producto = dp.id_producto
GROUP BY pr.id_producto, pr.nombre, pr.precio
ORDER BY veces_pedido DESC;

-- Vista de recomendaciones con promedio
CREATE OR REPLACE VIEW vista_productos_rating AS
SELECT 
    pr.id_producto,
    pr.nombre,
    COUNT(r.id_recomendacion) AS total_reviews,
    ROUND(AVG(r.puntuacion), 2) AS rating_promedio
FROM productos pr
LEFT JOIN recomendaciones r ON pr.id_producto = r.id_producto
GROUP BY pr.id_producto, pr.nombre
ORDER BY rating_promedio DESC;

-- =====================================================
-- FUNCIONES ÚTILES
-- =====================================================

-- Función para calcular total del pedido
CREATE OR REPLACE FUNCTION calcular_total_pedido(p_id_pedido INTEGER)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_total DECIMAL(10, 2);
BEGIN
    SELECT COALESCE(SUM(subtotal), 0)
    INTO v_total
    FROM detalle_pedidos
    WHERE id_pedido = p_id_pedido;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger para actualizar el total del pedido automáticamente
CREATE OR REPLACE FUNCTION actualizar_total_pedido()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pedidos
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM detalle_pedidos
        WHERE id_pedido = NEW.id_pedido
    )
    WHERE id_pedido = NEW.id_pedido;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_total
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedidos
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_pedido();



SELECT * FROM productos WHERE disponible = TRUE ORDER BY nombre
SELECT * FROM vista_pedidos_completos WHERE id_cliente = 1 AND estado IN ('pendiente', 'en preparacion', 'en camino')



-- Obtener ubicación actual del delivery
SELECT * FROM ubicaciones WHERE id_usuario = 3 AND activa = TRUE ORDER BY fecha_registro DESC LIMIT 1;

-- Obtener recomendaciones de un producto
 SELECT * FROM recomendaciones WHERE id_producto = 1 ORDER BY fecha_recomendacion DESC;




-- Obtener pedidos activos del Cliente con ID = 1 (usando la tabla base)
SELECT 
    p.*, 
    c.nombre AS cliente_nombre -- Solo si necesitas el nombre del cliente
FROM pedidos p
JOIN usuarios c ON p.id_cliente = c.id_usuario
WHERE p.id_cliente = 1 AND p.estado IN ('pendiente', 'en preparacion', 'en camino');




CREATE OR REPLACE FUNCTION registrar_cambio_estado()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado IS DISTINCT FROM NEW.estado THEN
        INSERT INTO historial_estados (id_pedido, estado_anterior, estado_nuevo)
        VALUES (NEW.id_pedido, OLD.estado, NEW.estado);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_historial_estado
AFTER UPDATE OF estado ON pedidos
FOR EACH ROW
EXECUTE FUNCTION registrar_cambio_estado();



ALTER TABLE pedidos
ADD COLUMN coordenadas_entrega JSONB;



CREATE TABLE historial_estados (
    id_historial SERIAL PRIMARY KEY,
    id_pedido INT REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);





CREATE EXTENSION IF NOT EXISTS pgcrypto;
UPDATE usuarios 
SET contrasena = crypt(contrasena, gen_salt('bf'));




ALTER TABLE pedidos
ADD COLUMN coordenadas_entrega JSONB DEFAULT NULL;





CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

-- Ejemplo de categorías iniciales
INSERT INTO categorias (nombre) VALUES
('Comida rápida'),
('Bebidas'),
('Postres'),
('Snacks'),
('Otros');



ALTER TABLE productos
ADD COLUMN id_categoria INT REFERENCES categorias(id_categoria);


ALTER TABLE productos
ADD COLUMN categoria VARCHAR(100);
CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

-- Conectar la tabla categorías a productos
ALTER TABLE productos
ADD COLUMN id_categoria INT REFERENCES categorias(id_categoria);

-- Opcional: copiar temporalmente el valor de texto actual
-- (si la columna categoria ya tiene datos)
UPDATE productos p
SET id_categoria = c.id_categoria
FROM categorias c
WHERE LOWER(p.categoria) = LOWER(c.nombre);


INSERT INTO categorias (nombre)
SELECT DISTINCT categoria
FROM productos
WHERE categoria IS NOT NULL
ON CONFLICT (nombre) DO NOTHING;


UPDATE productos p
SET id_categoria = c.id_categoria
FROM categorias c
WHERE LOWER(TRIM(p.categoria)) = LOWER(TRIM(c.nombre));


ALTER TABLE productos
ADD CONSTRAINT fk_categoria
FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
ON UPDATE CASCADE
ON DELETE SET NULL;
