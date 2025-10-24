-- =========================================================
-- DELIVERY DB — VERSIÓN FINAL PARA POSTGRESQL
-- =========================================================
-- Requisitos: PostgreSQL 12+ (recomendado)
-- =========================================================

-- 0) Extensiones
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- 1) LIMPIEZA PREVIA (IDEMPOTENTE)
-- =========================================================
DROP VIEW  IF EXISTS vista_pedidos_completos CASCADE;
DROP VIEW  IF EXISTS vista_productos_populares CASCADE;
DROP VIEW  IF EXISTS vista_productos_rating CASCADE;

-- Triggers (por si existen)
DROP TRIGGER IF EXISTS trg_usuarios_hash_password ON usuarios;
DROP TRIGGER IF EXISTS trigger_historial_estado ON pedidos;
DROP TRIGGER IF EXISTS trigger_actualizar_total ON detalle_pedidos;
DROP TRIGGER IF EXISTS trg_dp_single_shop ON detalle_pedidos;
DROP TRIGGER IF EXISTS trg_detalle_stock ON detalle_pedidos;
DROP TRIGGER IF EXISTS trg_roles_updated_at ON roles;
DROP TRIGGER IF EXISTS trg_negocios_updated_at ON negocios;
DROP TRIGGER IF EXISTS trg_categorias_updated_at ON categorias;
DROP TRIGGER IF EXISTS trg_productos_updated_at ON productos;
DROP TRIGGER IF EXISTS trg_ubicaciones_updated_at ON ubicaciones;
DROP TRIGGER IF EXISTS trg_pedidos_updated_at ON pedidos;
DROP TRIGGER IF EXISTS trg_detalle_pedidos_updated_at ON detalle_pedidos;
DROP TRIGGER IF EXISTS trg_recomendaciones_updated_at ON recomendaciones;
DROP TRIGGER IF EXISTS trg_mensajes_updated_at ON mensajes;
DROP TRIGGER IF EXISTS trg_usuarios_updated_at ON usuarios;
DROP TRIGGER IF EXISTS trg_usuarios_sync_id_rol ON usuarios;

-- Funciones
DROP FUNCTION IF EXISTS usuarios_hash_password_bcrypt();
DROP FUNCTION IF EXISTS registrar_cambio_estado();
DROP FUNCTION IF EXISTS actualizar_total_pedido();
DROP FUNCTION IF EXISTS fn_login(text, text);
DROP FUNCTION IF EXISTS set_updated_at();
DROP FUNCTION IF EXISTS check_pedido_single_negocio();
DROP FUNCTION IF EXISTS detalle_manage_stock();
DROP FUNCTION IF EXISTS claim_pedido(integer, integer);
DROP FUNCTION IF EXISTS set_estado_pedido(integer, text);
DROP FUNCTION IF EXISTS roles_set_updated_at();
DROP FUNCTION IF EXISTS negocios_set_updated_at();
DROP FUNCTION IF EXISTS usuarios_sync_id_rol();

-- Tablas (orden inverso)
DROP TABLE IF EXISTS inventario_movimientos CASCADE;
DROP TABLE IF EXISTS detalle_pedidos   CASCADE;
DROP TABLE IF EXISTS recomendaciones   CASCADE;
DROP TABLE IF EXISTS mensajes          CASCADE;
DROP TABLE IF EXISTS historial_estados CASCADE;
DROP TABLE IF EXISTS pedidos           CASCADE;
DROP TABLE IF EXISTS ubicaciones       CASCADE;
DROP TABLE IF EXISTS productos         CASCADE;
DROP TABLE IF EXISTS categorias        CASCADE;
DROP TABLE IF EXISTS usuarios          CASCADE;
DROP TABLE IF EXISTS roles             CASCADE;
DROP TABLE IF EXISTS permisos          CASCADE;
DROP TABLE IF EXISTS rol_permisos      CASCADE;
DROP TABLE IF EXISTS negocios          CASCADE;

-- =========================================================
-- 2) CATÁLOGOS DE ROLES/PERMISOS (RBAC LIGERO)
-- =========================================================
CREATE TABLE roles (
  id_rol SERIAL PRIMARY KEY,
  nombre VARCHAR(40) UNIQUE NOT NULL,   -- 'admin','delivery','cliente','soporte'
  descripcion TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE permisos (
  id_permiso SERIAL PRIMARY KEY,
  codigo VARCHAR(60) UNIQUE NOT NULL,   -- 'orders.view', 'orders.claim', ...
  descripcion TEXT
);

CREATE TABLE rol_permisos (
  id_rol INT REFERENCES roles(id_rol) ON DELETE CASCADE,
  id_permiso INT REFERENCES permisos(id_permiso) ON DELETE CASCADE,
  PRIMARY KEY (id_rol, id_permiso)
);

-- =========================================================
-- 3) TABLAS PRINCIPALES
-- =========================================================
CREATE TABLE negocios (
  id_negocio   SERIAL PRIMARY KEY,
  nombre       VARCHAR(150) NOT NULL,
  telefono     VARCHAR(20),
  direccion    TEXT,
  activo       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMZt DEFAULT NOW()
);

CREATE TABLE usuarios (
  id_usuario     SERIAL PRIMARY KEY,
  id_rol         INT REFERENCES roles(id_rol) ON UPDATE CASCADE,
  nombre         VARCHAR(100) NOT NULL,
  correo         VARCHAR(100) UNIQUE NOT NULL,
  contrasena     TEXT NOT NULL,
  rol            VARCHAR(20) NOT NULL CHECK (rol IN ('cliente','delivery','admin','soporte')),
  telefono       VARCHAR(20),
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  activo         BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_contrasena_bcrypt
    CHECK (contrasena ~ '^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$')
);

CREATE TABLE categorias (
  id_categoria SERIAL PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL UNIQUE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE productos (
  id_producto    SERIAL PRIMARY KEY,
  id_negocio     INT NOT NULL REFERENCES negocios(id_negocio) ON DELETE CASCADE,
  id_categoria   INT REFERENCES categorias(id_categoria) ON UPDATE CASCADE ON DELETE SET NULL,
  nombre         VARCHAR(100) NOT NULL,
  descripcion    TEXT,
  precio         DECIMAL(10,2) NOT NULL CHECK (precio >= 0),
  imagen_url     VARCHAR(500),
  disponible     BOOLEAN DEFAULT TRUE,
  stock          INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_producto_nombre_por_negocio UNIQUE (id_negocio, nombre)
);

CREATE TABLE ubicaciones (
  id_ubicacion   SERIAL PRIMARY KEY,
  id_usuario     INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  latitud        DOUBLE PRECISION NOT NULL CHECK (latitud BETWEEN -90 AND 90),
  longitud       DOUBLE PRECISION NOT NULL CHECK (longitud BETWEEN -180 AND 180),
  direccion      TEXT,
  descripcion    TEXT,
  activa         BOOLEAN DEFAULT TRUE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE pedidos (
  id_pedido           SERIAL PRIMARY KEY,
  id_cliente          INT NOT NULL REFERENCES usuarios(id_usuario),
  id_delivery         INT REFERENCES usuarios(id_usuario),
  id_ubicacion        INT REFERENCES ubicaciones(id_ubicacion) ON DELETE SET NULL,
  estado              VARCHAR(50) NOT NULL DEFAULT 'pendiente'
                      CHECK (estado IN ('pendiente','en preparacion','en camino','entregado','cancelado')),
  total               DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  direccion_entrega   TEXT NOT NULL,
  metodo_pago         VARCHAR(50) NOT NULL CHECK (metodo_pago IN ('efectivo','tarjeta','transferencia')),
  coordenadas_entrega JSONB,
  fecha_pedido        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_entrega       TIMESTAMP,
  notas               TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE detalle_pedidos (
  id_detalle      SERIAL PRIMARY KEY,
  id_pedido       INT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
  id_producto     INT NOT NULL REFERENCES productos(id_producto),
  cantidad        INT NOT NULL CHECK (cantidad > 0),
  precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
  subtotal        DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_subtotal_correcto CHECK (subtotal = cantidad * precio_unitario)
);

CREATE TABLE recomendaciones (
  id_recomendacion   SERIAL PRIMARY KEY,
  id_usuario         INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  id_producto        INT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
  puntuacion         INT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
  comentario         TEXT,
  fecha_recomendacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (id_usuario, id_producto)
);

CREATE TABLE mensajes (
  id_mensaje     SERIAL PRIMARY KEY,
  id_remitente   INT NOT NULL REFERENCES usuarios(id_usuario),
  id_destinatario INT NOT NULL REFERENCES usuarios(id_usuario),
  id_pedido      INT REFERENCES pedidos(id_pedido),
  mensaje        TEXT NOT NULL,
  fecha_envio    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  leido          BOOLEAN DEFAULT FALSE,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE historial_estados (
  id_historial    SERIAL PRIMARY KEY,
  id_pedido       INT REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
  estado_anterior VARCHAR(50),
  estado_nuevo    VARCHAR(50),
  fecha_cambio    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventario_movimientos (
  id_movimiento   SERIAL PRIMARY KEY,
  id_producto     INT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
  tipo            VARCHAR(20) NOT NULL CHECK (tipo IN ('venta','ajuste','ingreso','devolucion')),
  cantidad        INT NOT NULL,
  stock_antes     INT NOT NULL,
  stock_despues   INT NOT NULL,
  detalle         TEXT,
  creado_en       TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- 4) ÍNDICES
-- =========================================================
CREATE INDEX idx_negocios_activo            ON negocios(activo);
CREATE INDEX idx_usuarios_correo            ON usuarios(correo);
CREATE INDEX idx_productos_negocio          ON productos(id_negocio);
CREATE INDEX idx_productos_categoria        ON productos(id_categoria);
CREATE INDEX idx_productos_disponible       ON productos(disponible);
CREATE INDEX idx_ubicaciones_usuario        ON ubicaciones(id_usuario);
CREATE INDEX idx_ubicaciones_activa         ON ubicaciones(activa);
CREATE INDEX idx_pedidos_cliente            ON pedidos(id_cliente);
CREATE INDEX idx_pedidos_delivery           ON pedidos(id_delivery);
CREATE INDEX idx_pedidos_estado             ON pedidos(estado);
CREATE INDEX idx_pedidos_fecha              ON pedidos(fecha_pedido);
CREATE INDEX idx_pedidos_ubicacion          ON pedidos(id_ubicacion);
CREATE INDEX idx_detalle_pedido             ON detalle_pedidos(id_pedido);
CREATE INDEX idx_detalle_producto           ON detalle_pedidos(id_producto);
CREATE INDEX idx_recom_usuario              ON recomendaciones(id_usuario);
CREATE INDEX idx_recom_producto             ON recomendaciones(id_producto);
CREATE INDEX idx_mensajes_remitente         ON mensajes(id_remitente);
CREATE INDEX idx_mensajes_destinatario      ON mensajes(id_destinatario);

-- Exclusividad: un delivery solo puede tener 1 pedido activo ('en preparacion','en camino')
CREATE UNIQUE INDEX idx_uq_delivery_1_activo
ON pedidos(id_delivery)
WHERE id_delivery IS NOT NULL AND estado IN ('en preparacion','en camino');

-- =========================================================
-- 5) FUNCIONES Y TRIGGERS
-- =========================================================

-- 5.1) Timestamps automáticos
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.created_at IS NULL THEN NEW.created_at := NOW(); END IF;
    NEW.updated_at := NOW();
  ELSIF TG_OP = 'UPDATE' THEN
    IF to_jsonb(NEW) - 'updated_at' IS DISTINCT FROM to_jsonb(OLD) - 'updated_at' THEN
      NEW.updated_at := NOW();
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE r TEXT;
BEGIN
  FOREACH r IN ARRAY ARRAY[
    'roles','negocios','usuarios','categorias','productos','ubicaciones',
    'pedidos','detalle_pedidos','recomendaciones','mensajes'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I;', r, r);
    EXECUTE format('CREATE TRIGGER trg_%1$s_updated_at BEFORE INSERT OR UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION set_updated_at();', r);
  END LOOP;
END$$;

-- 5.2) BCrypt para usuarios
CREATE OR REPLACE FUNCTION usuarios_hash_password_bcrypt()
RETURNS TRIGGER AS $$
DECLARE
  bcrypt_regex CONSTANT text := '^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$';
BEGIN
  IF NEW.contrasena IS NULL OR length(NEW.contrasena) = 0 THEN
    RAISE EXCEPTION 'La contraseña no puede ser nula o vacía';
  END IF;
  IF NEW.contrasena !~ bcrypt_regex THEN
    NEW.contrasena := crypt(NEW.contrasena, gen_salt('bf', 12));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_hash_password
BEFORE INSERT OR UPDATE OF contrasena ON usuarios
FOR EACH ROW
EXECUTE FUNCTION usuarios_hash_password_bcrypt();

-- 5.3) Sincronizar usuarios.rol (texto) <-> usuarios.id_rol
CREATE OR REPLACE FUNCTION usuarios_sync_id_rol()
RETURNS TRIGGER AS $$
DECLARE v_id_rol INT;
BEGIN
  IF NEW.rol IS NOT NULL THEN
    SELECT id_rol INTO v_id_rol FROM roles WHERE nombre = NEW.rol;
    IF v_id_rol IS NULL THEN
      RAISE EXCEPTION 'Rol "%" no existe en catalogo roles', NEW.rol;
    END IF;
    NEW.id_rol := v_id_rol;
  ELSIF NEW.id_rol IS NOT NULL THEN
    SELECT nombre INTO NEW.rol FROM roles WHERE id_rol = NEW.id_rol;
  ELSE
    IF TG_OP = 'INSERT' THEN
      RAISE EXCEPTION 'Debe especificar rol o id_rol';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_sync_id_rol
BEFORE INSERT OR UPDATE OF rol, id_rol ON usuarios
FOR EACH ROW
EXECUTE FUNCTION usuarios_sync_id_rol();

-- 5.4) Historial de estado
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

-- 5.5) Total del pedido
CREATE OR REPLACE FUNCTION actualizar_total_pedido()
RETURNS TRIGGER AS $$
DECLARE
  v_id INT := COALESCE(NEW.id_pedido, OLD.id_pedido);
BEGIN
  UPDATE pedidos
  SET total = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM detalle_pedidos
    WHERE id_pedido = v_id
  )
  WHERE id_pedido = v_id;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_total
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedidos
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_pedido();

-- 5.6) Pedido de un solo negocio
CREATE OR REPLACE FUNCTION check_pedido_single_negocio()
RETURNS TRIGGER AS $$
DECLARE v_cnt INT;
BEGIN
  SELECT COUNT(DISTINCT pr.id_negocio)
  INTO v_cnt
  FROM detalle_pedidos dp
  JOIN productos pr ON pr.id_producto = dp.id_producto
  WHERE dp.id_pedido = COALESCE(NEW.id_pedido, OLD.id_pedido);

  IF v_cnt > 1 THEN
    RAISE EXCEPTION 'El pedido % mezcla productos de varios negocios. No permitido.',
      COALESCE(NEW.id_pedido, OLD.id_pedido)
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_dp_single_shop
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedidos
FOR EACH ROW
EXECUTE FUNCTION check_pedido_single_negocio();

-- 5.7) Manejo de stock con concurrencia (inventario)
CREATE OR REPLACE FUNCTION detalle_manage_stock()
RETURNS TRIGGER AS $$
DECLARE
  v_prod RECORD;
  v_delta INT;
  v_old_stock INT;
  v_new_stock INT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT * INTO v_prod FROM productos WHERE id_producto = NEW.id_producto FOR UPDATE;
    IF v_prod.disponible IS NOT TRUE THEN
      RAISE EXCEPTION 'Producto % no disponible', v_prod.id_producto;
    END IF;
    IF v_prod.stock < NEW.cantidad THEN
      RAISE EXCEPTION 'Stock insuficiente para producto %: disponible %, solicitado %', v_prod.id_producto, v_prod.stock, NEW.cantidad;
    END IF;
    IF NEW.precio_unitario = 0 THEN
      NEW.precio_unitario := v_prod.precio;
      NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
    END IF;
    v_old_stock := v_prod.stock;
    v_new_stock := v_prod.stock - NEW.cantidad;
    UPDATE productos SET stock = v_new_stock WHERE id_producto = v_prod.id_producto;
    INSERT INTO inventario_movimientos(id_producto, tipo, cantidad, stock_antes, stock_despues, detalle)
    VALUES (v_prod.id_producto, 'venta', -NEW.cantidad, v_old_stock, v_new_stock, format('Pedido %s (INSERT)', NEW.id_pedido));
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.id_producto <> OLD.id_producto THEN
      -- repone viejo
      SELECT * INTO v_prod FROM productos WHERE id_producto = OLD.id_producto FOR UPDATE;
      v_old_stock := v_prod.stock;
      v_new_stock := v_prod.stock + OLD.cantidad;
      UPDATE productos SET stock = v_new_stock WHERE id_producto = v_prod.id_producto;
      INSERT INTO inventario_movimientos(id_producto, tipo, cantidad, stock_antes, stock_despues, detalle)
      VALUES (v_prod.id_producto, 'devolucion', +OLD.cantidad, v_old_stock, v_new_stock, format('Pedido %s (UPDATE repone)', NEW.id_pedido));
      -- descuenta nuevo
      SELECT * INTO v_prod FROM productos WHERE id_producto = NEW.id_producto FOR UPDATE;
      IF v_prod.stock < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente al cambiar producto %: disp %, solicitado %', v_prod.id_producto, v_prod.stock, NEW.cantidad;
      END IF;
      IF NEW.precio_unitario = 0 THEN
        NEW.precio_unitario := v_prod.precio;
        NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
      END IF;
      v_old_stock := v_prod.stock;
      v_new_stock := v_prod.stock - NEW.cantidad;
      UPDATE productos SET stock = v_new_stock WHERE id_producto = v_prod.id_producto;
      INSERT INTO inventario_movimientos(id_producto, tipo, cantidad, stock_antes, stock_despues, detalle)
      VALUES (v_prod.id_producto, 'venta', -NEW.cantidad, v_old_stock, v_new_stock, format('Pedido %s (UPDATE descuenta)', NEW.id_pedido));
      RETURN NEW;
    ELSE
      -- mismo producto: dif de cantidad
      v_delta := COALESCE(NEW.cantidad,0) - COALESCE(OLD.cantidad,0);
      IF v_delta = 0 THEN RETURN NEW; END IF;
      SELECT * INTO v_prod FROM productos WHERE id_producto = NEW.id_producto FOR UPDATE;
      IF v_delta > 0 AND v_prod.stock < v_delta THEN
        RAISE EXCEPTION 'Stock insuficiente para producto %: disp %, adicional %', v_prod.id_producto, v_prod.stock, v_delta;
      END IF;
      v_old_stock := v_prod.stock;
      v_new_stock := v_prod.stock - v_delta;
      UPDATE productos SET stock = v_new_stock WHERE id_producto = v_prod.id_producto;
      INSERT INTO inventario_movimientos(id_producto, tipo, cantidad, stock_antes, stock_despues, detalle)
      VALUES (v_prod.id_producto,
              CASE WHEN v_delta>0 THEN 'venta' ELSE 'devolucion' END,
              -v_delta, v_old_stock, v_new_stock,
              format('Pedido %s (UPDATE delta %s)', NEW.id_pedido, v_delta));
      NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
      RETURN NEW;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    SELECT * INTO v_prod FROM productos WHERE id_producto = OLD.id_producto FOR UPDATE;
    v_old_stock := v_prod.stock;
    v_new_stock := v_prod.stock + OLD.cantidad;
    UPDATE productos SET stock = v_new_stock WHERE id_producto = v_prod.id_producto;
    INSERT INTO inventario_movimientos(id_producto, tipo, cantidad, stock_antes, stock_despues, detalle)
    VALUES (v_prod.id_producto, 'devolucion', +OLD.cantidad, v_old_stock, v_new_stock, format('Pedido %s (DELETE)', OLD.id_pedido));
    RETURN OLD;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_detalle_stock
BEFORE INSERT OR UPDATE OR DELETE ON detalle_pedidos
FOR EACH ROW
EXECUTE FUNCTION detalle_manage_stock();

-- 5.8) Login server-side (BCrypt)
CREATE OR REPLACE FUNCTION fn_login(p_correo TEXT, p_password TEXT)
RETURNS TABLE (id_usuario INT, nombre TEXT, correo TEXT, rol TEXT, activo BOOLEAN) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id_usuario, u.nombre, u.correo, u.rol, u.activo
  FROM usuarios u
  WHERE u.correo = p_correo
    AND u.contrasena = crypt(p_password, u.contrasena)
    AND u.activo = TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- 5.9) Reglas de transición de estado + helper
CREATE OR REPLACE FUNCTION set_estado_pedido(p_id_pedido INT, p_estado TEXT)
RETURNS VOID AS $$
DECLARE v_estado_actual TEXT;
BEGIN
  SELECT estado INTO v_estado_actual FROM pedidos WHERE id_pedido = p_id_pedido FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido % no existe', p_id_pedido; END IF;

  IF v_estado_actual = 'pendiente'      AND p_estado NOT IN ('en preparacion','cancelado') THEN
    RAISE EXCEPTION 'Transición inválida % -> %', v_estado_actual, p_estado;
  ELSIF v_estado_actual = 'en preparacion' AND p_estado NOT IN ('en camino','cancelado') THEN
    RAISE EXCEPTION 'Transición inválida % -> %', v_estado_actual, p_estado;
  ELSIF v_estado_actual = 'en camino'   AND p_estado NOT IN ('entregado','cancelado') THEN
    RAISE EXCEPTION 'Transición inválida % -> %', v_estado_actual, p_estado;
  ELSIF v_estado_actual IN ('entregado','cancelado') THEN
    RAISE EXCEPTION 'El pedido ya está %', v_estado_actual;
  END IF;

  UPDATE pedidos SET estado = p_estado,
                     fecha_entrega = CASE WHEN p_estado = 'entregado' THEN NOW() ELSE fecha_entrega END
  WHERE id_pedido = p_id_pedido;
END;
$$ LANGUAGE plpgsql;

-- 5.10) Reclamo de pedido por delivery (exclusivo y atómico)
CREATE OR REPLACE FUNCTION claim_pedido(p_id_pedido INT, p_id_delivery INT)
RETURNS BOOLEAN AS $$
DECLARE v_ok BOOLEAN := FALSE;
BEGIN
  UPDATE pedidos
  SET id_delivery = p_id_delivery,
      estado = CASE WHEN estado = 'pendiente' THEN 'en preparacion' ELSE estado END
  WHERE id_pedido = p_id_pedido
    AND id_delivery IS NULL
    AND estado IN ('pendiente','en preparacion')
  RETURNING TRUE INTO v_ok;

  RETURN COALESCE(v_ok, FALSE);
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 6) VISTAS
-- =========================================================
CREATE OR REPLACE VIEW vista_pedidos_completos AS
SELECT 
  p.id_pedido,
  p.fecha_pedido,
  p.estado,
  p.total,
  p.direccion_entrega,
  p.metodo_pago,
  c.nombre   AS cliente_nombre,
  c.correo   AS cliente_correo,
  c.telefono AS cliente_telefono,
  d.nombre   AS delivery_nombre,
  d.telefono AS delivery_telefono,
  n.id_negocio,
  n.nombre   AS negocio_nombre
FROM pedidos p
JOIN usuarios c ON p.id_cliente = c.id_usuario
LEFT JOIN usuarios d ON p.id_delivery = d.id_usuario
LEFT JOIN LATERAL (
  SELECT pr.id_negocio, ng.nombre
  FROM detalle_pedidos dp
  JOIN productos pr ON pr.id_producto = dp.id_producto
  JOIN negocios  ng ON ng.id_negocio = pr.id_negocio
  WHERE dp.id_pedido = p.id_pedido
  ORDER BY dp.id_detalle
  LIMIT 1
) n ON TRUE;

CREATE OR REPLACE VIEW vista_productos_populares AS
SELECT 
  pr.id_producto,
  pr.nombre,
  pr.precio,
  COUNT(dp.id_detalle)           AS veces_pedido,
  COALESCE(SUM(dp.cantidad),0)   AS total_unidades,
  COALESCE(SUM(dp.subtotal),0)   AS ingresos_totales
FROM productos pr
LEFT JOIN detalle_pedidos dp ON pr.id_producto = dp.id_producto
GROUP BY pr.id_producto, pr.nombre, pr.precio
ORDER BY veces_pedido DESC;

CREATE OR REPLACE VIEW vista_productos_rating AS
SELECT 
  pr.id_producto,
  pr.nombre,
  COUNT(r.id_recomendacion)              AS total_reviews,
  ROUND(AVG(r.puntuacion)::numeric, 2)   AS rating_promedio
FROM productos pr
LEFT JOIN recomendaciones r ON pr.id_producto = r.id_producto
GROUP BY pr.id_producto, pr.nombre
ORDER BY rating_promedio DESC NULLS LAST;

-- =========================================================
-- 7) SEED DATA (DATOS DE EJEMPLO)
-- =========================================================

-- Roles
INSERT INTO roles (nombre, descripcion) VALUES
  ('admin','Acceso total y administración'),
  ('delivery','Repartidor: reclamar pedidos, ver rutas'),
  ('cliente','Cliente: crea pedidos y reseñas'),
  ('soporte','Soporte: ver pedidos, contactar usuarios')
ON CONFLICT (nombre) DO NOTHING;

-- Permisos
INSERT INTO permisos (codigo, descripcion) VALUES
  ('orders.view',          'Ver pedidos'),
  ('orders.claim',         'Reclamar pedidos'),
  ('orders.update_status', 'Actualizar estado de pedidos'),
  ('products.view',        'Ver catálogo de productos'),
  ('products.manage',      'Crear/editar productos'),
  ('users.manage',         'Gestionar usuarios y roles'),
  ('reports.view',         'Ver reportes')
ON CONFLICT (codigo) DO NOTHING;

-- Asignación de permisos
INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso FROM roles r CROSS JOIN permisos p WHERE r.nombre='admin'
ON CONFLICT DO NOTHING;

INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso FROM roles r JOIN permisos p ON p.codigo IN ('orders.view','orders.claim','orders.update_status','products.view')
WHERE r.nombre='delivery' ON CONFLICT DO NOTHING;

INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso FROM roles r JOIN permisos p ON p.codigo IN ('products.view','orders.view')
WHERE r.nombre='cliente' ON CONFLICT DO NOTHING;

INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso FROM roles r JOIN permisos p ON p.codigo IN ('orders.view','reports.view')
WHERE r.nombre='soporte' ON CONFLICT DO NOTHING;

-- Negocios
INSERT INTO negocios (nombre, telefono, direccion) VALUES
('Pizzería Roma',   '099111222', 'Av. Italia 123'),
('Pizzería Napoli', '099333444', 'Av. Mediterráneo 456');

-- Categorías
INSERT INTO categorias (nombre) VALUES
('Pizzas'),('Hamburguesas'),('Acompañamientos'),
('Bebidas'),('Ensaladas'),('Pastas'),('Mexicana'),('Japonesa')
ON CONFLICT (nombre) DO NOTHING;

-- Usuarios (se hashean por trigger y sincronizan rol/id_rol)
INSERT INTO usuarios (id_rol, nombre, correo, contrasena, rol, telefono) VALUES
((SELECT id_rol FROM roles WHERE nombre='cliente'),  'Juan Pérez',    'juan@example.com',  'password123', 'cliente',  '0987654321'),
((SELECT id_rol FROM roles WHERE nombre='cliente'),  'María García',  'maria@example.com', 'password123', 'cliente',  '0987654322'),
((SELECT id_rol FROM roles WHERE nombre='delivery'), 'Carlos López',  'carlos@example.com','password123', 'delivery', '0987654323'),
((SELECT id_rol FROM roles WHERE nombre='admin'),    'Admin Sistema', 'admin@example.com', 'admin123',    'admin',    '0987654324');

-- Ubicaciones
INSERT INTO ubicaciones (id_usuario, latitud, longitud, direccion, descripcion) VALUES
((SELECT id_usuario FROM usuarios WHERE correo='juan@example.com'),  0.9681, -79.6512, 'Calle Principal #123, Esmeraldas', 'Casa'),
((SELECT id_usuario FROM usuarios WHERE correo='maria@example.com'), 0.9721, -79.6552, 'Av. Libertad #456, Esmeraldas',     'Trabajo'),
((SELECT id_usuario FROM usuarios WHERE correo='carlos@example.com'),0.9651, -79.6482, 'Centro de Distribución, Esmeraldas','Base');

-- Productos (con stock)
INSERT INTO productos (id_negocio, id_categoria, nombre, descripcion, precio, imagen_url, disponible, stock)
SELECT n.id_negocio, c.id_categoria, v.nombre, v.descripcion, v.precio, v.imagen_url, v.disponible, v.stock
FROM (
  VALUES
    ('Pizzería Roma','Pizzas','Pizza Margarita','Clásica con tomate y mozzarella', 12.50,'https://example.com/pizza_roma.jpg',   TRUE, 50),
    ('Pizzería Napoli','Pizzas','Pizza Margarita','Estilo Napoli',                  13.00,'https://example.com/pizza_napoli.jpg', TRUE, 40),
    ('Pizzería Roma','Bebidas','Coca Cola 500ml','Gaseosa',                         1.50,'https://example.com/cola_roma.jpg',    TRUE, 200),
    ('Pizzería Roma','Acompañamientos','Papas Fritas','Crocantes',                  3.50,'https://example.com/fries_roma.jpg',   TRUE, 80)
) AS v(negocio,categoria,nombre,descripcion,precio,imagen_url,disponible,stock)
JOIN LATERAL (
  SELECT id_negocio FROM negocios WHERE nombre=v.negocio ORDER BY id_negocio DESC LIMIT 1
) n ON TRUE
JOIN LATERAL (
  SELECT id_categoria FROM categorias WHERE nombre=v.categoria ORDER BY id_categoria DESC LIMIT 1
) c ON TRUE
ON CONFLICT (id_negocio, nombre) DO NOTHING;

-- Pedido de prueba (con detalles) SIN variables externas
WITH np AS (
  INSERT INTO pedidos (id_cliente, id_delivery, id_ubicacion, estado, total, direccion_entrega, metodo_pago)
  VALUES (
    (SELECT id_usuario FROM usuarios WHERE correo='juan@example.com'),
    NULL,
    (SELECT id_ubicacion FROM ubicaciones
      WHERE id_usuario=(SELECT id_usuario FROM usuarios WHERE correo='juan@example.com')
      ORDER BY id_ubicacion DESC LIMIT 1),
    'pendiente', 0, 'Calle Principal #123, Esmeraldas', 'efectivo'
  )
  RETURNING id_pedido
),
pmarg AS (
  SELECT pr.id_producto, pr.precio
  FROM productos pr JOIN negocios n ON n.id_negocio = pr.id_negocio
  WHERE n.nombre='Pizzería Roma' AND pr.nombre='Pizza Margarita'
  ORDER BY pr.id_producto DESC LIMIT 1
),
pcola AS (
  SELECT pr.id_producto, pr.precio
  FROM productos pr JOIN negocios n ON n.id_negocio = pr.id_negocio
  WHERE n.nombre='Pizzería Roma' AND pr.nombre='Coca Cola 500ml'
  ORDER BY pr.id_producto DESC LIMIT 1
)
INSERT INTO detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT np.id_pedido, pmarg.id_producto, 1, pmarg.precio, pmarg.precio FROM np, pmarg
UNION ALL
SELECT np.id_pedido, pcola.id_producto, 2, pcola.precio, pcola.precio*2 FROM np, pcola;

-- Recomendaciones de ejemplo (evita duplicados y resuelve por negocio/nombre determinísticamente)
INSERT INTO recomendaciones (id_usuario, id_producto, puntuacion, comentario)
SELECT 
    u.id_usuario,
    p.id_producto,
    v.puntuacion,
    v.comentario
FROM (
    VALUES
      ('juan@example.com',  'Pizzería Roma',   'Pizza Margarita',  5, '¡Excelente! Masa perfecta.'),
      ('juan@example.com',  'Pizzería Roma',   'Coca Cola 500ml',  4, 'Bien fría.'),
      ('maria@example.com', 'Pizzería Napoli', 'Pizza Margarita',  5, 'Sabores auténticos.'),
      ('maria@example.com', 'Pizzería Roma',   'Papas Fritas',     4, 'Crocantes y sabrosas.')
) AS v(correo, negocio, nombre_producto, puntuacion, comentario)
JOIN usuarios u ON u.correo = v.correo
JOIN LATERAL (
    SELECT pr.id_producto
    FROM productos pr
    JOIN negocios n ON n.id_negocio = pr.id_negocio
    WHERE n.nombre = v.negocio
      AND pr.nombre = v.nombre_producto
    ORDER BY pr.id_producto DESC
    LIMIT 1
) p ON TRUE
ON CONFLICT (id_usuario, id_producto) DO NOTHING;

-- =========================================================
-- 8) VISTA AUX: USUARIOS Y SUS PERMISOS
-- =========================================================
CREATE OR REPLACE VIEW vista_usuarios_permisos AS
SELECT 
  u.id_usuario, u.nombre, u.correo, u.rol,
  r.nombre AS rol_nombre,
  string_agg(DISTINCT p.codigo, ', ' ORDER BY p.codigo) AS permisos
FROM usuarios u
LEFT JOIN roles r ON r.id_rol = u.id_rol
LEFT JOIN rol_permisos rp ON rp.id_rol = r.id_rol
LEFT JOIN permisos p ON p.id_permiso = rp.id_permiso
GROUP BY u.id_usuario, u.nombre, u.correo, u.rol, r.nombre;

-- =========================================================
-- 9) SEGURIDAD BÁSICA: evitar exponer contraseñas
-- =========================================================
REVOKE ALL ON TABLE usuarios FROM PUBLIC;
GRANT SELECT (id_usuario, id_rol, nombre, correo, rol, telefono, activo, created_at, updated_at) ON usuarios TO PUBLIC;









































ALTER TABLE negocios
  ALTER COLUMN updated_at TYPE TIMESTAMPTZ
  USING updated_at::timestamptz,
  ALTER COLUMN updated_at SET DEFAULT NOW();

SELECT table_schema,
       table_name,
       column_name,
       data_type
FROM information_schema.columns
WHERE data_type ILIKE '%timestamzt%'  -- buscar errores de tipeo
   OR column_name ILIKE '%timestamzt%';  -- buscar nombres sospechosos



ALTER TABLE negocios
  ALTER COLUMN updated_at TYPE TIMESTAMPTZ
  USING updated_at::timestamptz;


ALTER TABLE <nombre_tabla>
  ALTER COLUMN <nombre_columna> TYPE TIMESTAMPTZ
  USING <nombre_columna>::timestamptz,
  ALTER COLUMN <nombre_columna> SET DEFAULT NOW();






SELECT table_schema,
       table_name,
       column_name,
       data_type
FROM information_schema.columns
WHERE data_type ILIKE '%timestamzt%'
   OR column_name ILIKE '%timestamzt%';

