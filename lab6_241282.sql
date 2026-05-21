
-- =========================================================
-- Limpieza inicial
-- =========================================================

DROP TRIGGER IF EXISTS trg_10_validar_unidades ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_11_descontar_inventario ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_12_actualizar_total ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_13_auditar_inventario ON producto;
DROP TRIGGER IF EXISTS trg_14_validar_pago ON pago;

DROP FUNCTION IF EXISTS fn_10_validar_unidades();
DROP FUNCTION IF EXISTS fn_11_descontar_inventario();
DROP FUNCTION IF EXISTS fn_12_actualizar_total();
DROP FUNCTION IF EXISTS fn_13_auditar_inventario();
DROP FUNCTION IF EXISTS fn_14_validar_pago();
DROP FUNCTION IF EXISTS crear_pedido_seguro(integer, integer, integer);
DROP FUNCTION IF EXISTS activar_cliente(integer);
DROP FUNCTION IF EXISTS productos_disponibles();

DROP VIEW IF EXISTS vista_clientes_activos;

DROP TABLE IF EXISTS pago CASCADE;
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS auditoria_inventario CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;

DO $$
DECLARE
    r name;
BEGIN
    FOREACH r IN ARRAY ARRAY['vendedor_ana', 'vendedor_luis', 'auditor_externo', 'rol_vendedores']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END;
$$;

-- =========================================================
-- Esquema base convertido a PostgreSQL
-- =========================================================

CREATE TABLE cliente (
    id_cliente integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre varchar(100) NOT NULL,
    email varchar(100) UNIQUE NOT NULL,
    telefono varchar(20),
    activo boolean NOT NULL DEFAULT true
);

CREATE TABLE producto (
    id_producto integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre varchar(100) NOT NULL,
    precio numeric(10, 2) NOT NULL CHECK (precio >= 0),
    unidades integer NOT NULL CHECK (unidades >= 0)
);

CREATE TABLE pedido (
    id_pedido integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente integer NOT NULL REFERENCES cliente(id_cliente),
    total numeric(10, 2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    fecha timestamp NOT NULL DEFAULT current_timestamp
);

CREATE TABLE detalle_pedido (
    id_detalle integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido integer NOT NULL REFERENCES pedido(id_pedido) ON DELETE CASCADE,
    id_producto integer NOT NULL REFERENCES producto(id_producto),
    cantidad integer NOT NULL CHECK (cantidad > 0),
    precio_unitario numeric(10, 2) NOT NULL CHECK (precio_unitario >= 0)
);

CREATE TABLE pago (
    id_pago integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido integer NOT NULL REFERENCES pedido(id_pedido),
    monto numeric(10, 2) NOT NULL CHECK (monto >= 0),
    fecha timestamp NOT NULL DEFAULT current_timestamp
);

CREATE TABLE auditoria_inventario (
    id_auditoria integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto integer NOT NULL REFERENCES producto(id_producto),
    unidades_antes integer NOT NULL,
    unidades_despues integer NOT NULL,
    fecha timestamp NOT NULL DEFAULT current_timestamp
);

-- Datos de prueba
INSERT INTO cliente (nombre, email, telefono, activo) VALUES
('Ana Torres', 'ana@mail.com', '5550-1001', true),
('Luis Perez', 'luis@mail.com', '5550-1002', true),
('Maria Gomez', 'maria@mail.com', '5550-1003', true),
('Carlos Ruiz', 'carlos@mail.com', '5550-1004', true),
('Sofia Diaz', 'sofia@mail.com', '5550-1005', true),
('Pedro Castillo', 'pedro@mail.com', '5550-1006', false),
('Lucia Herrera', 'lucia@mail.com', '5550-1007', true),
('Jorge Mendoza', 'jorge@mail.com', '5550-1008', true),
('Valentina Rojas', 'vale@mail.com', '5550-1009', true),
('Diego Silva', 'diego@mail.com', '5550-1010', true),
('Elena Morales', 'elena@mail.com', '5550-1011', false);

INSERT INTO producto (nombre, precio, unidades) VALUES
('Laptop', 1200.00, 10),
('Mouse', 25.00, 50),
('Teclado', 45.00, 30),
('Monitor', 300.00, 15),
('Auriculares', 80.00, 25),
('Webcam', 60.00, 20),
('Silla Gamer', 250.00, 8),
('Escritorio', 400.00, 5),
('USB 64GB', 15.00, 100),
('Disco SSD 1TB', 150.00, 12),
('Tablet Demo', 275.00, 0);

INSERT INTO pedido (id_cliente, total, fecha) VALUES
(1, 1250.00, current_timestamp),
(2, 70.00, current_timestamp),
(3, 300.00, current_timestamp),
(4, 95.00, current_timestamp),
(5, 1500.00, current_timestamp);

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(1, 1, 1, 1200.00),
(1, 2, 2, 25.00),
(2, 3, 1, 45.00),
(2, 2, 1, 25.00),
(3, 4, 1, 300.00),
(4, 5, 1, 80.00),
(4, 9, 1, 15.00),
(5, 1, 1, 1200.00),
(5, 7, 1, 250.00),
(5, 2, 2, 25.00);

INSERT INTO pago (id_pedido, monto) VALUES
(1, 1250.00),
(2, 70.00),
(3, 300.00),
(4, 95.00),
(5, 1500.00);

-- =========================================================
-- Bloque 1: Usuarios y roles
-- =========================================================

-- Mision 1: rol de vendedores con permisos limitados.
CREATE ROLE rol_vendedores NOLOGIN;
CREATE ROLE vendedor_ana LOGIN PASSWORD 'Venta_241282_1';
CREATE ROLE vendedor_luis LOGIN PASSWORD 'Venta_241282_2';

GRANT rol_vendedores TO vendedor_ana;
GRANT rol_vendedores TO vendedor_luis;

GRANT USAGE ON SCHEMA public TO rol_vendedores;
GRANT SELECT ON producto TO rol_vendedores;
GRANT INSERT ON pedido TO rol_vendedores;
GRANT INSERT ON detalle_pedido TO rol_vendedores;
GRANT USAGE, SELECT ON SEQUENCE pedido_id_pedido_seq TO rol_vendedores;
GRANT USAGE, SELECT ON SEQUENCE detalle_pedido_id_detalle_seq TO rol_vendedores;

-- No se otorgan UPDATE ni DELETE sobre producto, por eso no pueden modificar precios o unidades.

-- Mision 2: usuario auditor con lectura minima y vencimiento de contrato.
CREATE ROLE auditor_externo LOGIN PASSWORD 'Auditor_241282' VALID UNTIL '2026-07-20';

DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO auditor_externo', current_database());
END;
$$;

GRANT USAGE ON SCHEMA public TO auditor_externo;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO auditor_externo;

-- Mision 3: los vendedores no deben ver email ni telefono de cliente.
GRANT SELECT (id_cliente, nombre, activo) ON cliente TO rol_vendedores;
REVOKE SELECT (email, telefono) ON cliente FROM rol_vendedores;

-- Mision 4: vista solo con clientes activos y datos necesarios.
CREATE VIEW vista_clientes_activos AS
SELECT id_cliente, nombre
FROM cliente
WHERE activo = true;

REVOKE ALL ON cliente FROM rol_vendedores;
REVOKE SELECT (id_cliente, nombre, activo) ON cliente FROM rol_vendedores;
GRANT SELECT ON vista_clientes_activos TO rol_vendedores;

-- Mision 5: se bloquea la insercion directa de pedidos.
REVOKE INSERT ON pedido FROM rol_vendedores;
REVOKE USAGE, SELECT ON SEQUENCE pedido_id_pedido_seq FROM rol_vendedores;

-- =========================================================
-- Bloque 2: Procedimientos almacenados
-- =========================================================

-- Mision 6: productos disponibles.
CREATE OR REPLACE FUNCTION productos_disponibles()
RETURNS TABLE (
    id_producto integer,
    nombre varchar,
    precio numeric,
    unidades integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id_producto, p.nombre, p.precio, p.unidades
    FROM producto p
    WHERE p.unidades > 0
    ORDER BY p.id_producto;
END;
$$;

-- Mision 7: activar un cliente inactivo si existe.
CREATE OR REPLACE FUNCTION activar_cliente(p_id_cliente integer)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_activo boolean;
BEGIN
    SELECT c.activo
    INTO v_activo
    FROM cliente c
    WHERE c.id_cliente = p_id_cliente;

    IF NOT FOUND THEN
        RETURN 'No existe un cliente con ese id.';
    END IF;

    IF v_activo THEN
        RETURN 'El cliente ya estaba activo.';
    END IF;

    UPDATE cliente
    SET activo = true
    WHERE id_cliente = p_id_cliente;

    RETURN 'Cliente activado correctamente.';
END;
$$;

-- Mision 8: insercion segura de pedidos.
-- En PostgreSQL una funcion se ejecuta dentro de la transaccion del cliente.
-- Si ocurre un error, las inserciones realizadas por la funcion se revierten juntas.
CREATE OR REPLACE FUNCTION crear_pedido_seguro(
    p_id_cliente integer,
    p_id_producto integer,
    p_cantidad integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cliente_activo boolean;
    v_precio numeric(10, 2);
    v_unidades integer;
    v_id_pedido integer;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a cero.';
    END IF;

    SELECT c.activo
    INTO v_cliente_activo
    FROM cliente c
    WHERE c.id_cliente = p_id_cliente;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente % no existe.', p_id_cliente;
    END IF;

    IF NOT v_cliente_activo THEN
        RAISE EXCEPTION 'El cliente % esta inactivo.', p_id_cliente;
    END IF;

    SELECT p.precio, p.unidades
    INTO v_precio, v_unidades
    FROM producto p
    WHERE p.id_producto = p_id_producto
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no existe.', p_id_producto;
    END IF;

    IF v_unidades < p_cantidad THEN
        RAISE EXCEPTION 'Inventario insuficiente. Disponibles: %, solicitadas: %.',
            v_unidades, p_cantidad;
    END IF;

    INSERT INTO pedido (id_cliente)
    VALUES (p_id_cliente)
    RETURNING id_pedido INTO v_id_pedido;

    INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
    VALUES (v_id_pedido, p_id_producto, p_cantidad, v_precio);

    RETURN v_id_pedido;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- Mision 9: los vendedores crean pedidos solo mediante la funcion autorizada.
REVOKE INSERT ON pedido FROM rol_vendedores;
REVOKE INSERT ON detalle_pedido FROM rol_vendedores;
REVOKE USAGE, SELECT ON SEQUENCE pedido_id_pedido_seq FROM rol_vendedores;
REVOKE USAGE, SELECT ON SEQUENCE detalle_pedido_id_detalle_seq FROM rol_vendedores;
GRANT EXECUTE ON FUNCTION crear_pedido_seguro(integer, integer, integer) TO rol_vendedores;
GRANT EXECUTE ON FUNCTION productos_disponibles() TO rol_vendedores;

-- =========================================================
-- Bloque 3: Triggers
-- =========================================================

-- Mision 10: validar inventario antes de insertar detalle.
CREATE OR REPLACE FUNCTION fn_10_validar_unidades()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_unidades integer;
BEGIN
    SELECT unidades
    INTO v_unidades
    FROM producto
    WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no existe.', NEW.id_producto;
    END IF;

    IF v_unidades < NEW.cantidad THEN
        RAISE EXCEPTION 'No hay unidades suficientes para el producto %. Disponibles: %, solicitadas: %.',
            NEW.id_producto, v_unidades, NEW.cantidad;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_10_validar_unidades
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_10_validar_unidades();

-- Mision 11: descontar inventario al insertar detalle.
CREATE OR REPLACE FUNCTION fn_11_descontar_inventario()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE producto
    SET unidades = unidades - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_11_descontar_inventario
AFTER INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_11_descontar_inventario();

-- Mision 12: actualizar el total del pedido al insertar detalle.
CREATE OR REPLACE FUNCTION fn_12_actualizar_total()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE pedido
    SET total = (
        SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
        FROM detalle_pedido
        WHERE id_pedido = NEW.id_pedido
    )
    WHERE id_pedido = NEW.id_pedido;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_12_actualizar_total
AFTER INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_12_actualizar_total();

-- Mision 13: auditar cada cambio de unidades.
CREATE OR REPLACE FUNCTION fn_13_auditar_inventario()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.unidades IS DISTINCT FROM NEW.unidades THEN
        INSERT INTO auditoria_inventario (id_producto, unidades_antes, unidades_despues)
        VALUES (NEW.id_producto, OLD.unidades, NEW.unidades);
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_13_auditar_inventario
AFTER UPDATE OF unidades ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_13_auditar_inventario();

-- Mision 14: validar que el pago coincida con el total del pedido.
CREATE OR REPLACE FUNCTION fn_14_validar_pago()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric(10, 2);
BEGIN
    SELECT total
    INTO v_total
    FROM pedido
    WHERE id_pedido = NEW.id_pedido;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pedido % no existe.', NEW.id_pedido;
    END IF;

    IF NEW.monto <> v_total THEN
        RAISE EXCEPTION 'El pago no coincide con el total del pedido. Total: %, monto recibido: %.',
            v_total, NEW.monto;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_14_validar_pago
BEFORE INSERT ON pago
FOR EACH ROW
EXECUTE FUNCTION fn_14_validar_pago();

-- =========================================================
-- Pruebas comentadas para documentar en el PDF
-- Ejecutar una por una al tomar capturas.
-- =========================================================

-- Mision 1:
-- SET ROLE vendedor_ana;
-- SELECT id_producto, nombre, precio, unidades FROM producto;
-- UPDATE producto SET precio = precio + 10 WHERE id_producto = 1;
-- RESET ROLE;

-- Mision 2:
-- SET ROLE auditor_externo;
-- SELECT * FROM cliente;
-- INSERT INTO producto (nombre, precio, unidades) VALUES ('Prueba auditor', 1.00, 1);
-- RESET ROLE;

-- Mision 3:
-- SET ROLE vendedor_ana;
-- SELECT email, telefono FROM cliente;
-- RESET ROLE;

-- Mision 4:
-- SET ROLE vendedor_ana;
-- SELECT * FROM vista_clientes_activos;
-- RESET ROLE;

-- Mision 5 y 9:
-- SET ROLE vendedor_ana;
-- INSERT INTO pedido (id_cliente) VALUES (1);
-- SELECT crear_pedido_seguro(1, 2, 2) AS pedido_creado;
-- RESET ROLE;

-- Mision 6:
-- SELECT * FROM productos_disponibles();

-- Mision 7:
-- SELECT activar_cliente(6);
-- SELECT id_cliente, nombre, activo FROM cliente WHERE id_cliente = 6;

-- Mision 8:
-- SELECT crear_pedido_seguro(1, 3, 2) AS pedido_valido;

-- Esta prueba debe fallar porque el cliente está inactivo.
-- SELECT crear_pedido_seguro(11, 3, 1) AS pedido_cliente_inactivo;

-- Esta prueba debe fallar porque el producto no tiene inventario.
-- SELECT crear_pedido_seguro(1, 11, 1) AS pedido_sin_inventario;

-- Mision 10:
-- INSERT INTO pedido (id_cliente) VALUES (1);
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
-- VALUES ((SELECT max(id_pedido) FROM pedido), 11, 1, 275.00);

-- Mision 11:
-- SELECT id_producto, nombre, unidades FROM producto WHERE id_producto = 2;

-- Mision 12:
-- SELECT id_pedido, total FROM pedido ORDER BY id_pedido DESC LIMIT 5;

-- Mision 13:
-- SELECT * FROM auditoria_inventario ORDER BY id_auditoria DESC;

-- Mision 14:
-- Pago correcto.
-- INSERT INTO pago (id_pedido, monto)
-- VALUES (
--     (SELECT max(id_pedido) FROM pedido),
--     (SELECT total FROM pedido WHERE id_pedido = (SELECT max(id_pedido) FROM pedido))
-- );

-- Pago incorrecto. Esta prueba debe fallar.
-- INSERT INTO pago (id_pedido, monto)
-- VALUES ((SELECT max(id_pedido) FROM pedido), 1.00);