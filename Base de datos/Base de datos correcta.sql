-- =================================================================
-- CONFIGURACIÓN INICIAL DE LA SESIÓN
-- =================================================================

-- Establece la codificación de caracteres del cliente a UTF-8, el estándar universal.
SET client_encoding = 'UTF8';
-- Asegura que el manejo de strings (cadenas de texto) siga el estándar SQL.
SET standard_conforming_strings = 'on';
-- Limpia el 'search_path' (ruta de búsqueda de esquemas) para evitar conflictos.
SELECT pg_catalog.set_config('search_path', '', false);


-- =================================================================
-- EXTENSIONES Y ESQUEMAS
-- =================================================================

-- (Metadato de pg_dump) Define la creación de la base de datos 'neondb'.
-- CREATE DATABASE neondb WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = builtin LOCALE = 'C.UTF-8' BUILTIN_LOCALE = 'C.UTF-8';

-- Otorga todos los privilegios sobre la base de datos al rol 'neon_superuser'.
GRANT ALL ON DATABASE neondb TO neon_superuser;

-- Instala la extensión 'pg_session_jwt' si no existe.
-- Esta extensión se usa para manejar sesiones de autenticación usando JSON Web Tokens (JWT).
CREATE EXTENSION IF NOT EXISTS pg_session_jwt WITH SCHEMA public;

-- Añade un comentario descriptivo a la extensión.
COMMENT ON EXTENSION pg_session_jwt IS 'pg_session_jwt: manage authentication sessions using JWTs';

-- Crea un esquema llamado 'pgrst'.
-- 'pgrst' es comúnmente usado por PostgREST, una herramienta que crea una API REST
-- automáticamente a partir de una base de datos PostgreSQL.
CREATE SCHEMA pgrst;

-- Otorga permisos de 'USO' (acceso) sobre el esquema 'pgrst' al rol 'authenticator'.
-- Esto permite que el rol usado para la autenticación pueda "ver" este esquema.
GRANT USAGE ON SCHEMA pgrst TO authenticator;

-- Instala la extensión 'pgcrypto' si no existe.
-- Provee funciones criptográficas, como 'crypt()' y 'gen_salt()',
-- usadas comúnmente para hashear (cifrar) contraseñas.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- Añade un comentario descriptivo a la extensión.
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


-- =================================================================
-- FUNCIONES
-- =================================================================

-- FUNCIÓN: pgrst.pre_config()
-- Propósito: Configurar parámetros iniciales para PostgREST (la API REST).
-- Detalles: Establece los esquemas que PostgREST expondrá ('public'),
--          habilita agregados, define el rol anónimo y la clave del JWT para el rol.
CREATE FUNCTION pgrst.pre_config() RETURNS void
    LANGUAGE sql
    AS $$
  SELECT
      set_config('pgrst.db_schemas', 'public', true)
    , set_config('pgrst.db_aggregates_enabled', 'true', true)
    , set_config('pgrst.db_anon_role', 'anonymous', true)
    , set_config('pgrst.jwt_role_claim_key', '."role"', true)
$$;

-- Otorga permisos de ejecución sobre la función al rol 'authenticator'.
GRANT ALL ON FUNCTION pgrst.pre_config() TO authenticator;

-- FUNCIÓN TRIGGER: public.actualizar_total_pedido()
-- Propósito: Recalcula el campo 'total' en la tabla 'pedidos' automáticamente.
-- Disparador: Se ejecuta después (AFTER) de insertar, actualizar o borrar
--             un registro en 'detalle_pedidos'.
-- Lógica: Suma todos los 'subtotal' de los detalles asociados a un pedido
--        y actualiza el 'total' del pedido correspondiente.
CREATE FUNCTION public.actualizar_total_pedido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;

-- FUNCIÓN TRIGGER: public.check_pedido_single_negocio()
-- Propósito: Asegurar que un pedido no mezcle productos de diferentes negocios.
-- Disparador: Se ejecuta después (AFTER) de insertar, actualizar o borrar
--             en 'detalle_pedidos'.
-- Lógica: Cuenta cuántos negocios distintos están involucrados en un pedido.
--        Si es más de 1, lanza una excepción (error).
CREATE FUNCTION public.check_pedido_single_negocio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;

-- FUNCIÓN: public.claim_pedido(integer, integer)
-- Propósito: Permite a un repartidor (delivery) "reclamar" un pedido.
-- Parámetros: p_id_pedido (ID del pedido), p_id_delivery (ID del repartidor).
-- Lógica: Actualiza el pedido asignando el 'id_delivery' y cambiando el estado
--        a 'en preparacion' (si estaba 'pendiente').
--        Solo funciona si el pedido no tiene ya un repartidor asignado.
CREATE FUNCTION public.claim_pedido(p_id_pedido integer, p_id_delivery integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;

-- FUNCIÓN TRIGGER: public.detalle_manage_stock()
-- Propósito: Administrar el inventario (stock) automáticamente al modificar un pedido.
-- Disparador: Se ejecuta ANTES (BEFORE) de insertar, actualizar o borrar en 'detalle_pedidos'.
-- Lógica:
--   - INSERT: Verifica si hay stock. Si lo hay, resta la cantidad del stock del producto
--             y registra el movimiento en 'inventario_movimientos'.
--   - UPDATE: Maneja dos casos:
--             1. Si cambia el producto: Repone el stock del producto antiguo y descuenta el del nuevo.
--             2. Si solo cambia la cantidad: Ajusta el stock según la diferencia (delta).
--   - DELETE: Repone el stock del producto que se está quitando del pedido
--             y registra el movimiento como 'devolucion'.
CREATE FUNCTION public.detalle_manage_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;

-- FUNCIÓN: public.fn_admin_dashboard()
-- Propósito: Obtener datos resumidos para el panel de administración.
-- Lógica: Consulta vistas (vw_admin_resumen_diario, vw_admin_producto_top)
--        para devolver un resumen de ventas, pedidos y el producto más vendido.
CREATE FUNCTION public.fn_admin_dashboard() RETURNS TABLE(ventas_hoy numeric, ventas_totales numeric, pedidos_pendientes integer, pedidos_entregados integer, nuevos_clientes integer, producto_mas_vendido text, producto_mas_vendido_cantidad integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.ventas_hoy,
    r.ventas_totales,
    r.pedidos_pendientes,
    r.pedidos_entregados,
    r.nuevos_clientes,
    COALESCE(pt.nombre,'Sin datos') AS producto_mas_vendido,
    COALESCE(pt.unidades_vendidas,0) AS producto_mas_vendido_cantidad
  FROM vw_admin_resumen_diario r
  LEFT JOIN vw_admin_producto_top pt ON TRUE;
END;
$$;

-- FUNCIÓN: public.fn_login(text, text)
-- Propósito: Manejar el inicio de sesión de un usuario.
-- Parámetros: p_correo (correo), p_password (contraseña).
-- Lógica: Busca un usuario por correo, compara la contraseña usando 'crypt()'
--        (que funciona con el hash bcrypt) y devuelve los datos del usuario si es activo.
CREATE FUNCTION public.fn_login(p_correo text, p_password text) RETURNS TABLE(id_usuario integer, nombre text, correo text, rol text, activo boolean)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT u.id_usuario, u.nombre, u.correo, u.rol, u.activo
  FROM usuarios u
  WHERE u.correo = p_correo
    AND u.contrasena = crypt(p_password, u.contrasena)
    AND u.activo = TRUE;
END;
$$;

-- FUNCIÓN TRIGGER: public.registrar_cambio_estado()
-- Propósito: Guardar un historial de todos los cambios de estado de un pedido.
-- Disparador: Se ejecuta DESPUÉS (AFTER) de actualizar el campo 'estado' en 'pedidos'.
-- Lógica: Si el estado nuevo es diferente del antiguo, inserta un registro
--        en 'historial_estados' con el estado anterior y el nuevo.
CREATE FUNCTION public.registrar_cambio_estado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO historial_estados (id_pedido, estado_anterior, estado_nuevo)
    VALUES (NEW.id_pedido, OLD.estado, NEW.estado);
  END IF;
  RETURN NEW;
END;
$$;

-- FUNCIÓN: public.set_estado_pedido(integer, text)
-- Propósito: Cambiar el estado de un pedido de forma controlada.
-- Parámetros: p_id_pedido (ID del pedido), p_estado (nuevo estado).
-- Lógica: Verifica que la transición de estado sea válida
--        (ej. de 'pendiente' solo se puede pasar a 'en preparacion' o 'cancelado').
--        Si la transición no es válida, lanza un error.
--        Si el nuevo estado es 'entregado', actualiza la 'fecha_entrega'.
CREATE FUNCTION public.set_estado_pedido(p_id_pedido integer, p_estado text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;

-- FUNCIÓN TRIGGER: public.set_updated_at()
-- Propósito: Actualizar automáticamente el campo 'updated_at' (fecha de modificación).
-- Disparador: Se ejecuta ANTES (BEFORE) de insertar o actualizar en cualquier tabla.
-- Lógica: Establece 'created_at' y 'updated_at' en INSERT.
--        Actualiza 'updated_at' en UPDATE, solo si algún otro campo cambió.
CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;

-- FUNCIÓN TRIGGER: public.update_ubicaciones_updated_at()
-- Propósito: Función específica para actualizar 'updated_at' en 'ubicaciones'.
--            (Nota: es redundante si ya existe 'set_updated_at()').
CREATE FUNCTION public.update_ubicaciones_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- FUNCIÓN TRIGGER: public.usuarios_hash_password_bcrypt()
-- Propósito: Cifrar (hashear) la contraseña del usuario antes de guardarla.
-- Disparador: Se ejecuta ANTES (BEFORE) de insertar o actualizar el campo 'contrasena'
--             en la tabla 'usuarios'.
-- Lógica: Verifica si la contraseña es nula o vacía.
--        Si la contraseña no parece ser ya un hash bcrypt, la cifra
--        usando `crypt(password, gen_salt('bf', 12))`.
CREATE FUNCTION public.usuarios_hash_password_bcrypt() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
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
$_$;

-- FUNCIÓN TRIGGER: public.usuarios_sync_id_rol()
-- Propósito: Sincronizar 'id_rol' y 'rol' (nombre) en la tabla 'usuarios'.
-- Disparador: Se ejecuta ANTES (BEFORE) de insertar o actualizar 'rol' o 'id_rol'
--             en la tabla 'usuarios'.
-- Lógica: Si se provee el nombre 'rol', busca y asigna el 'id_rol' correspondiente.
--        Si se provee 'id_rol', busca y asigna el 'nombre' del rol.
--        Lanza un error si el rol no existe o si no se provee ninguno.
CREATE FUNCTION public.usuarios_sync_id_rol() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


-- =================================================================
-- DEFINICIÓN DE TABLAS Y SECUENCIAS
-- =================================================================

-- TABLA: categorias
-- Propósito: Almacena las categorías de los productos (ej. "Bebidas", "Postres").
CREATE TABLE public.categorias (
    id_categoria integer NOT NULL,
    nombre character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- SECUENCIA: categorias_id_categoria_seq
-- Propósito: Generador de números autoincrementables para 'id_categoria'.
CREATE SEQUENCE public.categorias_id_categoria_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Asocia la secuencia 'categorias_id_categoria_seq' a la columna 'id_categoria'.
ALTER SEQUENCE public.categorias_id_categoria_seq OWNED BY public.categorias.id_categoria;


-- TABLA: detalle_pedidos
-- Propósito: Almacena los ítems (líneas) de un pedido.
--            Relaciona 'pedidos' con 'productos'.
CREATE TABLE public.detalle_pedidos (
    id_detalle integer NOT NULL,
    id_pedido integer NOT NULL,        -- Llave foránea a 'pedidos'
    id_producto integer NOT NULL,      -- Llave foránea a 'productos'
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL, -- Calculado (cantidad * precio_unitario)
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    -- Restricciones (CONSTRAINT):
    -- Asegura que el subtotal sea coherente.
    CONSTRAINT chk_subtotal_correcto CHECK ((subtotal = ((cantidad)::numeric * precio_unitario))),
    -- Asegura que la cantidad sea positiva.
    CONSTRAINT detalle_pedidos_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT detalle_pedidos_precio_unitario_check CHECK ((precio_unitario >= (0)::numeric)),
    CONSTRAINT detalle_pedidos_subtotal_check CHECK ((subtotal >= (0)::numeric))
);

-- SECUENCIA: detalle_pedidos_id_detalle_seq
-- Propósito: Generador de números autoincrementables para 'id_detalle'.
CREATE SEQUENCE public.detalle_pedidos_id_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.detalle_pedidos_id_detalle_seq OWNED BY public.detalle_pedidos.id_detalle;


-- TABLA: historial_estados
-- Propósito: Registra todos los cambios de estado de un pedido para auditoría.
CREATE TABLE public.historial_estados (
    id_historial integer NOT NULL,
    id_pedido integer,                -- Llave foránea a 'pedidos'
    estado_anterior character varying(50),
    estado_nuevo character varying(50),
    fecha_cambio timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

-- SECUENCIA: historial_estados_id_historial_seq
CREATE SEQUENCE public.historial_estados_id_historial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.historial_estados_id_historial_seq OWNED BY public.historial_estados.id_historial;


-- TABLA: inventario_movimientos
-- Propósito: Registra cada entrada y salida de stock (inventario).
CREATE TABLE public.inventario_movimientos (
    id_movimiento integer NOT NULL,
    id_producto integer NOT NULL,     -- Llave foránea a 'productos'
    tipo character varying(20) NOT NULL, -- 'venta', 'ajuste', 'ingreso', 'devolucion'
    cantidad integer NOT NULL,         -- Cantidad (negativa para salidas, positiva para entradas)
    stock_antes integer NOT NULL,      -- Stock antes del movimiento
    stock_despues integer NOT NULL,     -- Stock después del movimiento
    detalle text,                      -- Razón del movimiento (ej. "Pedido 123")
    creado_en timestamp with time zone DEFAULT now(),
    -- Restricción: El tipo de movimiento debe ser uno de los predefinidos.
    CONSTRAINT inventario_movimientos_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['venta'::character varying, 'ajuste'::character varying, 'ingreso'::character varying, 'devolucion'::character varying])::text[])))
);

-- SECUENCIA: inventario_movimientos_id_movimiento_seq
CREATE SEQUENCE public.inventario_movimientos_id_movimiento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.inventario_movimientos_id_movimiento_seq OWNED BY public.inventario_movimientos.id_movimiento;


-- TABLA: mensajes
-- Propósito: Almacena mensajes de chat (ej. entre cliente y repartidor).
CREATE TABLE public.mensajes (
    id_mensaje integer NOT NULL,
    id_remitente integer NOT NULL,    -- Llave foránea a 'usuarios'
    id_destinatario integer NOT NULL, -- Llave foránea a 'usuarios'
    id_pedido integer,                -- Llave foránea a 'pedidos' (opcional)
    mensaje text NOT NULL,
    fecha_envio timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    leido boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- SECUENCIA: mensajes_id_mensaje_seq
CREATE SEQUENCE public.mensajes_id_mensaje_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.mensajes_id_mensaje_seq OWNED BY public.mensajes.id_mensaje;


-- TABLA: negocios
-- Propósito: Almacena la información de los negocios/restaurantes.
CREATE TABLE public.negocios (
    id_negocio integer NOT NULL,
    nombre character varying(150) NOT NULL,
    telefono character varying(20),
    direccion text,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- SECUENCIA: negocios_id_negocio_seq
CREATE SEQUENCE public.negocios_id_negocio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.negocios_id_negocio_seq OWNED BY public.negocios.id_negocio;


-- TABLA: pedidos
-- Propósito: Tabla principal, almacena la cabecera de los pedidos.
CREATE TABLE public.pedidos (
    id_pedido integer NOT NULL,
    id_cliente integer NOT NULL,      -- Llave foránea a 'usuarios'
    id_delivery integer,              -- Llave foránea a 'usuarios' (repartidor)
    id_ubicacion integer,             -- Llave foránea a 'ubicaciones' (dirección guardada)
    estado character varying(50) DEFAULT 'pendiente'::character varying NOT NULL,
    total numeric(10,2) DEFAULT 0 NOT NULL, -- Calculado por trigger
    direccion_entrega text,
    metodo_pago character varying(50) NOT NULL,
    coordenadas_entrega jsonb,        -- Guarda latitud/longitud en formato JSON
    fecha_pedido timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega timestamp without time zone,
    notas text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    fecha_creacion timestamp without time zone DEFAULT now(),
    -- Restricciones:
    -- El estado debe ser uno de los predefinidos.
    CONSTRAINT pedidos_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'en preparacion'::character varying, 'en camino'::character varying, 'entregado'::character varying, 'cancelado'::character varying])::text[]))),
    -- El método de pago debe ser uno de los predefinidos.
    CONSTRAINT pedidos_metodo_pago_check CHECK ((lower((metodo_pago)::text) = ANY (ARRAY['efectivo'::text, 'tarjeta'::text, 'transferencia'::text]))),
    CONSTRAINT pedidos_total_check CHECK ((total >= (0)::numeric))
);

-- SECUENCIA: pedidos_id_pedido_seq
CREATE SEQUENCE public.pedidos_id_pedido_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.pedidos_id_pedido_seq OWNED BY public.pedidos.id_pedido;


-- TABLA: permisos
-- Propósito: Catálogo de permisos (ej. "ver_dashboard", "editar_productos").
CREATE TABLE public.permisos (
    id_permiso integer NOT NULL,
    codigo character varying(60) NOT NULL, -- Nombre único del permiso
    descripcion text
);

-- SECUENCIA: permisos_id_permiso_seq
CREATE SEQUENCE public.permisos_id_permiso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.permisos_id_permiso_seq OWNED BY public.permisos.id_permiso;


-- TABLA: playing_with_neon
-- Propósito: Parece ser una tabla de prueba (común en bases de datos de ejemplo).
CREATE TABLE public.playing_with_neon (
    id integer NOT NULL,
    name text NOT NULL,
    value real
);

-- SECUENCIA: playing_with_neon_id_seq
CREATE SEQUENCE public.playing_with_neon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.playing_with_neon_id_seq OWNED BY public.playing_with_neon.id;


-- TABLA: productos
-- Propósito: Almacena el catálogo de productos de todos los negocios.
CREATE TABLE public.productos (
    id_producto integer NOT NULL,
    id_negocio integer NOT NULL,      -- Llave foránea a 'negocios'
    id_categoria integer,             -- Llave foránea a 'categorias'
    nombre character varying(100) NOT NULL,
    descripcion text,
    precio numeric(10,2) NOT NULL,
    imagen_url character varying(500),
    disponible boolean DEFAULT true,
    stock integer DEFAULT 0 NOT NULL, -- Controlado por el trigger 'detalle_manage_stock'
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    categoria character varying(50),  -- (Campo quizás redundante si se usa id_categoria)
    proveedor character varying(100),
    codigo_barras character varying(50),
    descuento numeric(5,2) DEFAULT 0,
    destacado boolean DEFAULT false,
    unidad_medida character varying(20),
    fecha_expiracion date,
    costo numeric(10,2),
    ganancia numeric(10,2),
    rating numeric(3,2) DEFAULT 0,    -- Rating promedio (quizás calculado)
    etiquetas text[],                 -- Array de tags o etiquetas
    ultima_compra timestamp with time zone,
    ultima_actualizacion timestamp with time zone,
    CONSTRAINT productos_precio_check CHECK ((precio >= (0)::numeric)),
    CONSTRAINT productos_stock_check CHECK ((stock >= 0))
);

-- SECUENCIA: productos_id_producto_seq
CREATE SEQUENCE public.productos_id_producto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.productos_id_producto_seq OWNED BY public.productos.id_producto;


-- TABLA: recomendaciones
-- Propósito: Almacena las reseñas o "ratings" que los usuarios dan a los productos.
CREATE TABLE public.recomendaciones (
    id_recomendacion integer NOT NULL,
    id_usuario integer NOT NULL,      -- Llave foránea a 'usuarios'
    id_producto integer NOT NULL,     -- Llave foránea a 'productos'
    puntuacion integer NOT NULL,      -- Rating (ej. 1 a 5)
    comentario text,
    fecha_recomendacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    fecha timestamp without time zone DEFAULT now(),
    CONSTRAINT recomendaciones_puntuacion_check CHECK (((puntuacion >= 1) AND (puntuacion <= 5)))
);

-- SECUENCIA: recomendaciones_id_recomendacion_seq
CREATE SEQUENCE public.recomendaciones_id_recomendacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.recomendaciones_id_recomendacion_seq OWNED BY public.recomendaciones.id_recomendacion;


-- TABLA: rol_permisos
-- Propósito: Tabla pivote (muchos a muchos) que asigna permisos a los roles.
CREATE TABLE public.rol_permisos (
    id_rol integer NOT NULL,          -- Llave foránea a 'roles'
    id_permiso integer NOT NULL       -- Llave foránea a 'permisos'
);


-- TABLA: roles
-- Propósito: Catálogo de roles (ej. "admin", "cliente", "delivery").
CREATE TABLE public.roles (
    id_rol integer NOT NULL,
    nombre character varying(40) NOT NULL, -- Nombre único del rol
    descripcion text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- SECUENCIA: roles_id_rol_seq
CREATE SEQUENCE public.roles_id_rol_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.roles_id_rol_seq OWNED BY public.roles.id_rol;


-- TABLA: ubicaciones
-- Propósito: Almacena las direcciones guardadas de los usuarios.
CREATE TABLE public.ubicaciones (
    id_ubicacion integer NOT NULL,
    id_usuario integer NOT NULL,      -- Llave foránea a 'usuarios'
    latitud double precision NOT NULL,
    longitud double precision NOT NULL,
    direccion text,
    descripcion text,                 -- Ej. "Casa", "Oficina"
    activa boolean DEFAULT true,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    estado character varying(50) DEFAULT 'activo'::character varying,
    -- Restricciones: Valida que latitud y longitud estén en rangos correctos.
    CONSTRAINT ubicaciones_latitud_check CHECK (((latitud >= ('-90'::integer)::double precision) AND (latitud <= (90)::double precision))),
    CONSTRAINT ubicaciones_longitud_check CHECK (((longitud >= ('-180'::integer)::double precision) AND (longitud <= (180)::double precision)))
);

-- SECUENCIA: ubicaciones_id_ubicacion_seq
CREATE SEQUENCE public.ubicaciones_id_ubicacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.ubicaciones_id_ubicacion_seq OWNED BY public.ubicaciones.id_ubicacion;


-- TABLA: usuarios
-- Propósito: Almacena todos los usuarios (clientes, repartidores, admins).
CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    id_rol integer,                   -- Llave foránea a 'roles'
    nombre character varying(100) NOT NULL,
    correo character varying(100) NOT NULL,
    contrasena text NOT NULL,         -- Almacena el hash bcrypt
    rol character varying(20) NOT NULL, -- 'cliente', 'delivery', 'admin', 'soporte'
    telefono character varying(20),
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    latitud_actual numeric(10,6),     -- Ubicación en tiempo real (para repartidores)
    longitud_actual numeric(10,6),
    -- Restricciones:
    -- Valida que la contraseña almacenada tenga formato bcrypt.
    CONSTRAINT chk_contrasena_bcrypt CHECK ((contrasena ~ '^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$'::text)),
    -- El rol debe ser uno de los predefinidos.
    CONSTRAINT usuarios_rol_check CHECK (((rol)::text = ANY ((ARRAY['cliente'::character varying, 'delivery'::character varying, 'admin'::character varying, 'soporte'::character varying])::text[])))
);

-- SECUENCIA: usuarios_id_usuario_seq
CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;


-- =================================================================
-- DEFINICIÓN DE VISTAS (VIEWS)
-- =================================================================

-- VISTA: vista_estadisticas_admin
-- Propósito: Simplifica la consulta de estadísticas agregadas.
CREATE VIEW public.vista_estadisticas_admin AS
 SELECT count(DISTINCT id_pedido) FILTER (WHERE ((estado)::text = 'entregado'::text)) AS pedidos_entregados,
    COALESCE(( SELECT pr.nombre
           FROM (public.productos pr
             JOIN public.detalle_pedidos dp ON ((dp.id_producto = pr.id_producto)))
          GROUP BY pr.nombre
          ORDER BY (count(*)) DESC
         LIMIT 1), 'Sin datos'::character varying) AS producto_mas_vendido,
    COALESCE(( SELECT count(*) AS count
           FROM public.usuarios
          WHERE (((usuarios.rol)::text = 'cliente'::text) AND (usuarios.activo = true))), (0)::bigint) AS nuevos_clientes,
    COALESCE(sum(total), (0)::numeric) AS ventas_totales,
    count(DISTINCT id_pedido) FILTER (WHERE ((estado)::text = 'pendiente'::text)) AS pedidos_pendientes,
    COALESCE(sum(total) FILTER (WHERE ((fecha_creacion)::date = CURRENT_DATE)), (0)::numeric) AS ventas_hoy
   FROM public.pedidos p;


-- VISTA: vista_pedidos_completos
-- Propósito: Une 'pedidos' con 'usuarios' (cliente y repartidor) y 'negocios'
--            para obtener una vista desnormalizada y fácil de consultar.
CREATE VIEW public.vista_pedidos_completos AS
 SELECT p.id_pedido,
    p.fecha_pedido,
    p.estado,
    p.total,
    p.direccion_entrega,
    p.metodo_pago,
    c.nombre AS cliente_nombre,
    c.correo AS cliente_correo,
    c.telefono AS cliente_telefono,
    d.nombre AS delivery_nombre,
    d.telefono AS delivery_telefono,
    n.id_negocio,
    n.nombre AS negocio_nombre
   FROM (((public.pedidos p
     JOIN public.usuarios c ON ((p.id_cliente = c.id_usuario)))
     LEFT JOIN public.usuarios d ON ((p.id_delivery = d.id_usuario)))
     LEFT JOIN LATERAL ( SELECT pr.id_negocio,
            ng.nombre
           FROM ((public.detalle_pedidos dp
             JOIN public.productos pr ON ((pr.id_producto = dp.id_producto)))
             JOIN public.negocios ng ON ((ng.id_negocio = pr.id_negocio)))
          WHERE (dp.id_pedido = p.id_pedido)
          ORDER BY dp.id_detalle
         LIMIT 1) n ON (true));


-- VISTA: vista_productos_populares
-- Propósito: Calcula qué productos son los más pedidos (por veces y unidades).
CREATE VIEW public.vista_productos_populares AS
 SELECT pr.id_producto,
    pr.nombre,
    pr.precio,
    count(dp.id_detalle) AS veces_pedido,
    COALESCE(sum(dp.cantidad), (0)::bigint) AS total_unidades,
    COALESCE(sum(dp.subtotal), (0)::numeric) AS ingresos_totales
   FROM (public.productos pr
     LEFT JOIN public.detalle_pedidos dp ON ((pr.id_producto = dp.id_producto)))
  GROUP BY pr.id_producto, pr.nombre, pr.precio
  ORDER BY (count(dp.id_detalle)) DESC;


-- VISTA: vista_productos_rating
-- Propósito: Calcula el rating (puntuación) promedio de cada producto.
CREATE VIEW public.vista_productos_rating AS
 SELECT pr.id_producto,
    pr.nombre,
    count(r.id_recomendacion) AS total_reviews,
    round(avg(r.puntuacion), 2) AS rating_promedio
   FROM (public.productos pr
     LEFT JOIN public.recomendaciones r ON ((pr.id_producto = r.id_producto)))
  GROUP BY pr.id_producto, pr.nombre
  ORDER BY (round(avg(r.puntuacion), 2)) DESC NULLS LAST;


-- VISTA: vista_usuarios_permisos
-- Propósito: Muestra todos los permisos que tiene cada usuario,
--            basado en su rol.
CREATE VIEW public.vista_usuarios_permisos AS
 SELECT u.id_usuario,
    u.nombre,
    u.correo,
    u.rol,
    r.nombre AS rol_nombre,
    string_agg(DISTINCT (p.codigo)::text, ', '::text ORDER BY (p.codigo)::text) AS permisos
   FROM (((public.usuarios u
     LEFT JOIN public.roles r ON ((r.id_rol = u.id_rol)))
     LEFT JOIN public.rol_permisos rp ON ((rp.id_rol = r.id_rol)))
     LEFT JOIN public.permisos p ON ((p.id_permiso = rp.id_permiso)))
  GROUP BY u.id_usuario, u.nombre, u.correo, u.rol, r.nombre;


-- VISTA: vw_admin_producto_top
-- Propósito: Vista específica para obtener el producto más vendido (top 1).
CREATE VIEW public.vw_admin_producto_top AS
 SELECT pr.id_producto,
    pr.nombre,
    (sum(dp.cantidad))::integer AS unidades_vendidas
   FROM ((public.detalle_pedidos dp
     JOIN public.productos pr ON ((pr.id_producto = dp.id_producto)))
     JOIN public.pedidos p ON ((p.id_pedido = dp.id_pedido)))
  WHERE (lower((p.estado)::text) = 'entregado'::text)
  GROUP BY pr.id_producto, pr.nombre
  ORDER BY ((sum(dp.cantidad))::integer) DESC, pr.nombre
 LIMIT 1;


-- VISTA: vw_admin_resumen_diario
-- Propósito: Vista que resume las métricas clave para el admin
--            (ventas, pedidos, clientes).
CREATE VIEW public.vw_admin_resumen_diario AS
 WITH pedidos_data AS (
         SELECT (COALESCE(sum(
                CASE
                    WHEN ((lower((pedidos.estado)::text) = 'entregado'::text) AND (date(pedidos.fecha_pedido) = CURRENT_DATE)) THEN pedidos.total
                    ELSE NULL::numeric
                END), (0)::numeric))::numeric(12,2) AS ventas_hoy,
            (COALESCE(sum(
                CASE
                    WHEN (lower((pedidos.estado)::text) = 'entregado'::text) THEN pedidos.total
                    ELSE NULL::numeric
                END), (0)::numeric))::numeric(12,2) AS ventas_totales,
            (count(*) FILTER (WHERE (lower((pedidos.estado)::text) <> ALL (ARRAY['entregado'::text, 'cancelado'::text]))))::integer AS pedidos_pendientes,
            (count(*) FILTER (WHERE (lower((pedidos.estado)::text) = 'entregado'::text)))::integer AS pedidos_entregados
           FROM public.pedidos
        ), clientes_data AS (
         SELECT (count(*))::integer AS nuevos_clientes
           FROM public.usuarios
          WHERE (((usuarios.rol)::text = 'cliente'::text) AND (date(usuarios.fecha_registro) = CURRENT_DATE))
        )
 SELECT pedidos_data.ventas_hoy,
    pedidos_data.ventas_totales,
    pedidos_data.pedidos_pendientes,
    pedidos_data.pedidos_entregados,
    clientes_data.nuevos_clientes
   FROM pedidos_data,
    clientes_data;


-- VISTA: vw_productos_disponibles
-- Propósito: Filtra solo los productos que están marcados como 'disponible'.
CREATE VIEW public.vw_productos_disponibles AS
 SELECT id_producto,
    nombre,
    precio,
    COALESCE(categoria, 'Sin categoría'::character varying) AS categoria,
    COALESCE(imagen_url, ''::character varying) AS imagen_url,
    disponible
   FROM public.productos p
  WHERE (disponible IS TRUE);


-- =================================================================
-- CONFIGURACIÓN DE VALORES POR DEFECTO (SECUENCIAS)
-- =================================================================

-- Asigna la secuencia 'categorias_id_categoria_seq' para generar el ID
-- automáticamente al insertar en 'categorias'.
ALTER TABLE ONLY public.categorias ALTER COLUMN id_categoria SET DEFAULT nextval('public.categorias_id_categoria_seq'::regclass);
-- (Se repite para todas las tablas con IDs autoincrementables)
ALTER TABLE ONLY public.detalle_pedidos ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalle_pedidos_id_detalle_seq'::regclass);
ALTER TABLE ONLY public.historial_estados ALTER COLUMN id_historial SET DEFAULT nextval('public.historial_estados_id_historial_seq'::regclass);
ALTER TABLE ONLY public.inventario_movimientos ALTER COLUMN id_movimiento SET DEFAULT nextval('public.inventario_movimientos_id_movimiento_seq'::regclass);
ALTER TABLE ONLY public.mensajes ALTER COLUMN id_mensaje SET DEFAULT nextval('public.mensajes_id_mensaje_seq'::regclass);
ALTER TABLE ONLY public.negocios ALTER COLUMN id_negocio SET DEFAULT nextval('public.negocios_id_negocio_seq'::regclass);
ALTER TABLE ONLY public.pedidos ALTER COLUMN id_pedido SET DEFAULT nextval('public.pedidos_id_pedido_seq'::regclass);
ALTER TABLE ONLY public.permisos ALTER COLUMN id_permiso SET DEFAULT nextval('public.permisos_id_permiso_seq'::regclass);
ALTER TABLE ONLY public.playing_with_neon ALTER COLUMN id SET DEFAULT nextval('public.playing_with_neon_id_seq'::regclass);
ALTER TABLE ONLY public.productos ALTER COLUMN id_producto SET DEFAULT nextval('public.productos_id_producto_seq'::regclass);
ALTER TABLE ONLY public.recomendaciones ALTER COLUMN id_recomendacion SET DEFAULT nextval('public.recomendaciones_id_recomendacion_seq'::regclass);
ALTER TABLE ONLY public.roles ALTER COLUMN id_rol SET DEFAULT nextval('public.roles_id_rol_seq'::regclass);
ALTER TABLE ONLY public.ubicaciones ALTER COLUMN id_ubicacion SET DEFAULT nextval('public.ubicaciones_id_ubicacion_seq'::regclass);
ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


-- =================================================================
-- CARGA DE DATOS (Omitido para legibilidad)
-- =================================================================
-- ...
-- Aquí irían todos los comandos COPY public.tabla (...) FROM stdin;
-- ...


-- =================================================================
-- ACTUALIZACIÓN DE SECUENCIAS
-- =================================================================

-- Actualiza el contador de la secuencia al último valor insertado
-- (ej. la categoría 8 fue la última insertada).
SELECT pg_catalog.setval('public.categorias_id_categoria_seq', 8, true);
SELECT pg_catalog.setval('public.detalle_pedidos_id_detalle_seq', 10, true);
SELECT pg_catalog.setval('public.historial_estados_id_historial_seq', 1, true);
SELECT pg_catalog.setval('public.inventario_movimientos_id_movimiento_seq', 10, true);
SELECT pg_catalog.setval('public.mensajes_id_mensaje_seq', 1, false);
SELECT pg_catalog.setval('public.negocios_id_negocio_seq', 2, true);
SELECT pg_catalog.setval('public.pedidos_id_pedido_seq', 30, true);
SELECT pg_catalog.setval('public.permisos_id_permiso_seq', 7, true);
SELECT pg_catalog.setval('public.playing_with_neon_id_seq', 10, true);
SELECT pg_catalog.setval('public.productos_id_producto_seq', 8, true);
SELECT pg_catalog.setval('public.recomendaciones_id_recomendacion_seq', 28, true);
SELECT pg_catalog.setval('public.roles_id_rol_seq', 7, true);
SELECT pg_catalog.setval('public.ubicaciones_id_ubicacion_seq', 10, true);
SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 31, true);


-- =================================================================
-- RESTRICCIONES (CONSTRAINTS) - PKeys, FKeys, Unique
-- =================================================================

-- RESTRICCIÓN: UNIQUE (Única)
-- Asegura que no puede haber dos categorías con el mismo nombre.
ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);

-- RESTRICCIÓN: PRIMARY KEY (Llave Primaria)
-- Define 'id_categoria' como el identificador único de la tabla 'categorias'.
ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id_categoria);

-- (Se repite para todas las llaves primarias y únicas de las demás tablas)
ALTER TABLE ONLY public.detalle_pedidos
    ADD CONSTRAINT detalle_pedidos_pkey PRIMARY KEY (id_detalle);
ALTER TABLE ONLY public.historial_estados
    ADD CONSTRAINT historial_estados_pkey PRIMARY KEY (id_historial);
ALTER TABLE ONLY public.inventario_movimientos
    ADD CONSTRAINT inventario_movimientos_pkey PRIMARY KEY (id_movimiento);
ALTER TABLE ONLY public.mensajes
    ADD CONSTRAINT mensajes_pkey PRIMARY KEY (id_mensaje);
ALTER TABLE ONLY public.negocios
    ADD CONSTRAINT negocios_pkey PRIMARY KEY (id_negocio);
ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_pkey PRIMARY KEY (id_pedido);
ALTER TABLE ONLY public.permisos
    ADD CONSTRAINT permisos_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY public.permisos
    ADD CONSTRAINT permisos_pkey PRIMARY KEY (id_permiso);
ALTER TABLE ONLY public.playing_with_neon
    ADD CONSTRAINT playing_with_neon_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id_producto);
ALTER TABLE ONLY public.recomendaciones
    ADD CONSTRAINT recomendaciones_id_usuario_id_producto_key UNIQUE (id_usuario, id_producto);
ALTER TABLE ONLY public.recomendaciones
    ADD CONSTRAINT recomendaciones_pkey PRIMARY KEY (id_recomendacion);
ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_pkey PRIMARY KEY (id_rol, id_permiso);
ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id_rol);
ALTER TABLE ONLY public.ubicaciones
    ADD CONSTRAINT ubicaciones_pkey PRIMARY KEY (id_ubicacion);
ALTER TABLE ONLY public.productos
    ADD CONSTRAINT uq_producto_nombre_por_negocio UNIQUE (id_negocio, nombre);
ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_correo_key UNIQUE (correo);
ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


-- =================================================================
-- ÍNDICES (INDEXES)
-- =================================================================

-- ÍNDICE: idx_detalle_pedido
-- Propósito: Acelera las búsquedas de detalles de pedido por 'id_pedido'.
CREATE INDEX idx_detalle_pedido ON public.detalle_pedidos USING btree (id_pedido);

-- ÍNDICE: idx_detalle_producto
-- Propósito: Acelera las búsquedas de detalles de pedido por 'id_producto'.
CREATE INDEX idx_detalle_producto ON public.detalle_pedidos USING btree (id_producto);

-- (Se repite para todos los índices)
CREATE INDEX idx_mensajes_destinatario ON public.mensajes USING btree (id_destinatario);
CREATE INDEX idx_mensajes_remitente ON public.mensajes USING btree (id_remitente);
CREATE INDEX idx_negocios_activo ON public.negocios USING btree (activo);
CREATE INDEX idx_pedidos_cliente ON public.pedidos USING btree (id_cliente);
CREATE INDEX idx_pedidos_delivery ON public.pedidos USING btree (id_delivery);
CREATE INDEX idx_pedidos_estado ON public.pedidos USING btree (estado);
CREATE INDEX idx_pedidos_fecha ON public.pedidos USING btree (fecha_pedido);
CREATE INDEX idx_pedidos_ubicacion ON public.pedidos USING btree (id_ubicacion);
CREATE INDEX idx_productos_categoria ON public.productos USING btree (id_categoria);
CREATE INDEX idx_productos_disponible ON public.productos USING btree (disponible);
CREATE INDEX idx_productos_negocio ON public.productos USING btree (id_negocio);
CREATE INDEX idx_recom_producto ON public.recomendaciones USING btree (id_producto);
CREATE INDEX idx_recom_usuario ON public.recomendaciones USING btree (id_usuario);
CREATE INDEX idx_ubicaciones_activa ON public.ubicaciones USING btree (activa);
CREATE INDEX idx_ubicaciones_estado ON public.ubicaciones USING btree (estado);
CREATE INDEX idx_ubicaciones_lat_lon ON public.ubicaciones USING btree (latitud, longitud);
CREATE INDEX idx_ubicaciones_usuario ON public.ubicaciones USING btree (id_usuario);

-- ÍNDICE ÚNICO CONDICIONAL: idx_uq_delivery_1_activo
-- Propósito: Asegura que un repartidor ('id_delivery') solo pueda tener
--            UN pedido activo ('en preparacion' o 'en camino') a la vez.
CREATE UNIQUE INDEX idx_uq_delivery_1_activo ON public.pedidos USING btree (id_delivery) WHERE ((id_delivery IS NOT NULL) AND ((estado)::text = ANY ((ARRAY['en preparacion'::character varying, 'en camino'::character varying])::text[])));

CREATE INDEX idx_usuarios_correo ON public.usuarios USING btree (correo);


-- =================================================================
-- DISPARADORES (TRIGGERS)
-- =================================================================

-- TRIGGER: trg_categorias_updated_at
-- Propósito: Ejecuta la función 'set_updated_at' ANTES (BEFORE) de
--            insertar o actualizar en la tabla 'categorias'.
CREATE TRIGGER trg_categorias_updated_at BEFORE INSERT OR UPDATE ON public.categorias FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- (Se repite para todas las tablas que necesitan 'updated_at' automático)
CREATE TRIGGER trg_detalle_pedidos_updated_at BEFORE INSERT OR UPDATE ON public.detalle_pedidos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_mensajes_updated_at BEFORE INSERT OR UPDATE ON public.mensajes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_negocios_updated_at BEFORE INSERT OR UPDATE ON public.negocios FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_pedidos_updated_at BEFORE INSERT OR UPDATE ON public.pedidos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_productos_updated_at BEFORE INSERT OR UPDATE ON public.productos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_recomendaciones_updated_at BEFORE INSERT OR UPDATE ON public.recomendaciones FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_roles_updated_at BEFORE INSERT OR UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_ubicaciones_updated_at BEFORE INSERT OR UPDATE ON public.ubicaciones FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_usuarios_updated_at BEFORE INSERT OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- TRIGGER: trg_detalle_stock
-- Propósito: Ejecuta la función 'detalle_manage_stock' ANTES (BEFORE) de
--            insertar, borrar o actualizar en 'detalle_pedidos' para manejar el inventario.
CREATE TRIGGER trg_detalle_stock BEFORE INSERT OR DELETE OR UPDATE ON public.detalle_pedidos FOR EACH ROW EXECUTE FUNCTION public.detalle_manage_stock();

-- TRIGGER: trg_dp_single_shop
-- Propósito: Ejecuta 'check_pedido_single_negocio' DESPUÉS (AFTER) de modificar
--            'detalle_pedidos' para validar la regla de un solo negocio por pedido.
CREATE TRIGGER trg_dp_single_shop AFTER INSERT OR DELETE OR UPDATE ON public.detalle_pedidos FOR EACH ROW EXECUTE FUNCTION public.check_pedido_single_negocio();

-- TRIGGER: trg_usuarios_hash_password
-- Propósito: Ejecuta 'usuarios_hash_password_bcrypt' ANTES (BEFORE) de
--            insertar o actualizar la 'contrasena' en 'usuarios' para cifrarla.
CREATE TRIGGER trg_usuarios_hash_password BEFORE INSERT OR UPDATE OF contrasena ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.usuarios_hash_password_bcrypt();

-- TRIGGER: trg_usuarios_sync_id_rol
-- Propósito: Ejecuta 'usuarios_sync_id_rol' ANTES (BEFORE) de insertar o
--            actualizar 'rol' o 'id_rol' en 'usuarios' para mantenerlos sincronizados.
CREATE TRIGGER trg_usuarios_sync_id_rol BEFORE INSERT OR UPDATE OF rol, id_rol ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.usuarios_sync_id_rol();

-- TRIGGER: trigger_actualizar_total
-- Propósito: Ejecuta 'actualizar_total_pedido' DESPUÉS (AFTER) de modificar
--            'detalle_pedidos' para recalcular el total del pedido.
CREATE TRIGGER trigger_actualizar_total AFTER INSERT OR DELETE OR UPDATE ON public.detalle_pedidos FOR EACH ROW EXECUTE FUNCTION public.actualizar_total_pedido();

-- TRIGGER: trigger_historial_estado
-- Propósito: Ejecuta 'registrar_cambio_estado' DESPUÉS (AFTER) de actualizar
--            el 'estado' en 'pedidos' para guardar el historial.
CREATE TRIGGER trigger_historial_estado AFTER UPDATE OF estado ON public.pedidos FOR EACH ROW EXECUTE FUNCTION public.registrar_cambio_estado();

-- TRIGGER: trigger_update_ubicaciones_updated_at
-- Propósito: Ejecuta 'update_ubicaciones_updated_at' (función redundante)
--            ANTES (BEFORE) de actualizar 'ubicaciones'.
CREATE TRIGGER trigger_update_ubicaciones_updated_at BEFORE UPDATE ON public.ubicaciones FOR EACH ROW EXECUTE FUNCTION public.update_ubicaciones_updated_at();


-- =================================================================
-- RESTRICCIONES DE LLAVE FORÁNEA (FOREIGN KEYS)
-- =================================================================

-- RESTRICCIÓN FK: detalle_pedidos -> pedidos
-- Propósito: Vincula 'detalle_pedidos.id_pedido' con 'pedidos.id_pedido'.
-- Comportamiento: ON DELETE CASCADE (Si se borra un pedido, se borran sus detalles).
ALTER TABLE ONLY public.detalle_pedidos
    ADD CONSTRAINT detalle_pedidos_id_pedido_fkey FOREIGN KEY (id_pedido) REFERENCES public.pedidos(id_pedido) ON DELETE CASCADE;

-- RESTRICCIÓN FK: detalle_pedidos -> productos
-- Propósito: Vincula 'detalle_pedidos.id_producto' con 'productos.id_producto'.
ALTER TABLE ONLY public.detalle_pedidos
    ADD CONSTRAINT detalle_pedidos_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.productos(id_producto);

-- RESTRICCIÓN FK: productos -> categorias
-- Propósito: Vincula 'productos.id_categoria' con 'categorias.id_categoria'.
-- Comportamiento: ON DELETE SET NULL (Si se borra una categoría, el 'id_categoria'
--                 en productos se pone NULO, pero el producto no se borra).
ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES public.categorias(id_categoria) ON DELETE SET NULL;

-- RESTRICCIÓN FK: productos -> negocios
-- Propósito: Vincula 'productos.id_negocio' con 'negocios.id_negocio'.
-- Comportamiento: ON DELETE CASCADE (Si se borra un negocio, se borran sus productos).
ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_producto_negocio FOREIGN KEY (id_negocio) REFERENCES public.negocios(id_negocio) ON DELETE CASCADE;

-- (Se repite para todas las llaves foráneas...)
ALTER TABLE ONLY public.historial_estados
    ADD CONSTRAINT historial_estados_id_pedido_fkey FOREIGN KEY (id_pedido) REFERENCES public.pedidos(id_pedido) ON DELETE CASCADE;
ALTER TABLE ONLY public.inventario_movimientos
    ADD CONSTRAINT inventario_movimientos_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.productos(id_producto) ON DELETE CASCADE;
ALTER TABLE ONLY public.mensajes
    ADD CONSTRAINT mensajes_id_destinatario_fkey FOREIGN KEY (id_destinatario) REFERENCES public.usuarios(id_usuario);
ALTER TABLE ONLY public.mensajes
    ADD CONSTRAINT mensajes_id_pedido_fkey FOREIGN KEY (id_pedido) REFERENCES public.pedidos(id_pedido);
ALTER TABLE ONLY public.mensajes
    ADD CONSTRAINT mensajes_id_remitente_fkey FOREIGN KEY (id_remitente) REFERENCES public.usuarios(id_usuario);
ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.usuarios(id_usuario);
ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_id_delivery_fkey FOREIGN KEY (id_delivery) REFERENCES public.usuarios(id_usuario);
ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_id_ubicacion_fkey FOREIGN KEY (id_ubicacion) REFERENCES public.ubicaciones(id_ubicacion) ON DELETE SET NULL;
ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES public.categorias(id_categoria) ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_id_negocio_fkey FOREIGN KEY (id_negocio) REFERENCES public.negocios(id_negocio) ON DELETE CASCADE;
ALTER TABLE ONLY public.recomendaciones
    ADD CONSTRAINT recomendaciones_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.productos(id_producto) ON DELETE CASCADE;
ALTER TABLE ONLY public.recomendaciones
    ADD CONSTRAINT recomendaciones_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;
ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_id_permiso_fkey FOREIGN KEY (id_permiso) REFERENCES public.permisos(id_permiso) ON DELETE CASCADE;
ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.roles(id_rol) ON DELETE CASCADE;
ALTER TABLE ONLY public.ubicaciones
    ADD CONSTRAINT ubicaciones_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;
ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.roles(id_rol) ON UPDATE CASCADE;

-- Fin del script
