# Lab 6 - Usuarios, procedimientos y triggers

**Universidad del Valle de Guatemala**  
**Bases de Datos 1**  
**Carne:** 241282  
**Estudiante:** ______________________________  
**Fecha:** ______________________________  

## Introduccion

En este laboratorio se trabajo la base de datos de TechZone usando PostgreSQL. La solucion se enfoca en controlar permisos con roles, mover validaciones importantes a funciones almacenadas y usar triggers para proteger la integridad de pedidos, inventario, auditoria y pagos.

---

## Mision 1 - Rol para vendedores

**Que se probo:** que un vendedor pueda consultar productos, pero no pueda modificar precios o inventario.

**Consulta de ejemplo:**

```sql
SET ROLE vendedor_ana;
SELECT id_producto, nombre, precio, unidades FROM producto;
UPDATE producto SET precio = precio + 10 WHERE id_producto = 1;
RESET ROLE;
```

**Resultado esperado:** el `SELECT` funciona y el `UPDATE` falla por falta de permisos.

**Explicacion:** se creo el rol `rol_vendedores` y se asigno a dos usuarios. El rol puede ver productos, pero no tiene permisos de modificacion sobre la tabla `producto`. Esto es importante porque evita que vendedores cambien precios o unidades por error.

[Espacio para captura de ejecucion de la Mision 1]

---

## Mision 2 - Usuario auditor

**Que se probo:** que el auditor pueda leer la informacion sin modificarla.

**Consulta de ejemplo:**

```sql
SET ROLE auditor_externo;
SELECT * FROM cliente;
INSERT INTO producto (nombre, precio, unidades) VALUES ('Prueba auditor', 1.00, 1);
RESET ROLE;
```

**Resultado esperado:** el auditor puede consultar, pero el `INSERT` falla. El usuario tiene `VALID UNTIL '2026-07-20'`.

**Explicacion:** el auditor externo recibe permisos minimos de lectura y un vencimiento de acceso de dos meses. Esto permite revisar datos sin abrir permisos innecesarios ni dejar una cuenta activa indefinidamente.

[Espacio para captura de ejecucion de la Mision 2]

---

## Mision 3 - Ocultar datos de contacto

**Que se probo:** que los vendedores no puedan ver `email` ni `telefono`.

**Consulta de ejemplo:**

```sql
SET ROLE vendedor_ana;
SELECT email, telefono FROM cliente;
RESET ROLE;
```

**Resultado esperado:** la consulta de `email` y `telefono` falla por falta de permisos.

**Explicacion:** se restringe el acceso a columnas sensibles del cliente y luego se evita el acceso directo a la tabla completa. Esto reduce el riesgo de contacto excesivo y protege informacion personal que no es necesaria para vender.

[Espacio para captura de ejecucion de la Mision 3]

---

## Mision 4 - Vista de clientes activos

**Que se probo:** que el vendedor use una vista con clientes activos en lugar de consultar la tabla completa.

**Consulta de ejemplo:**

```sql
SET ROLE vendedor_ana;
SELECT * FROM vista_clientes_activos;
RESET ROLE;
```

**Resultado esperado:** aparecen solo clientes con `activo = true`, mostrando `id_cliente` y `nombre`.

**Explicacion:** la vista limita la informacion disponible para vendedores y evita que trabajen con clientes inactivos. Tambien mantiene ocultos los campos de contacto.

[Espacio para captura de ejecucion de la Mision 4]

---

## Mision 5 - Revocar insercion directa de pedidos

**Que se probo:** que los vendedores no puedan insertar directamente en `pedido`.

**Consulta de ejemplo:**

```sql
SET ROLE vendedor_ana;
INSERT INTO pedido (id_cliente) VALUES (1);
RESET ROLE;
```

**Resultado esperado:** PostgreSQL rechaza el `INSERT` por falta de permisos.

**Explicacion:** se elimina la ruta insegura de crear pedidos manualmente. Esto importa porque un pedido insertado directo puede saltarse validaciones de cliente, producto e inventario.

[Espacio para captura de ejecucion de la Mision 5]

---

## Mision 6 - Productos disponibles

**Que se probo:** que la funcion devuelva solo productos con unidades mayores a cero.

**Consulta de ejemplo:**

```sql
SELECT * FROM productos_disponibles();
```

**Resultado esperado:** no aparece el producto `Tablet Demo`, porque tiene `0` unidades.

**Explicacion:** la funcion centraliza la consulta de productos vendibles. Esto evita mostrar productos agotados y ayuda a que ventas trabaje con datos utiles.

[Espacio para captura de ejecucion de la Mision 6]

---

## Mision 7 - Activar cliente inactivo

**Que se probo:** que un cliente inactivo pueda activarse solo si existe.

**Consulta de ejemplo:**

```sql
SELECT activar_cliente(6);
SELECT id_cliente, nombre, activo FROM cliente WHERE id_cliente = 6;
```

**Resultado esperado:** la funcion devuelve un mensaje de activacion y el cliente queda con `activo = true`.

**Explicacion:** la funcion evita actualizar clientes de forma desordenada. Primero valida si existe y despues revisa si realmente esta inactivo.

[Espacio para captura de ejecucion de la Mision 7]

---

## Mision 8 - Crear pedido seguro

**Que se probo:** que la funcion cree pedidos solo cuando cliente, producto y cantidad son validos.

**Consulta de ejemplo:**

```sql
SELECT crear_pedido_seguro(1, 3, 2) AS pedido_valido;
SELECT crear_pedido_seguro(11, 3, 1) AS pedido_cliente_inactivo;
SELECT crear_pedido_seguro(1, 11, 1) AS pedido_sin_inventario;
```

**Resultado esperado:** la primera consulta crea un pedido y devuelve su id. Las otras dos fallan porque el cliente esta inactivo o el producto no tiene inventario.

**Explicacion:** la funcion valida cliente activo, existencia del producto, inventario suficiente y cantidad positiva. En PostgreSQL la funcion se ejecuta dentro de la transaccion del cliente, por lo que si ocurre un error se revierte el pedido y su detalle.

[Espacio para captura de ejecucion de la Mision 8]

---

## Mision 9 - Creacion segura con permisos

**Que se probo:** que el vendedor no inserte directo, pero si pueda usar la funcion autorizada.

**Consulta de ejemplo:**

```sql
SET ROLE vendedor_ana;
INSERT INTO pedido (id_cliente) VALUES (1);
SELECT crear_pedido_seguro(1, 2, 2) AS pedido_creado;
RESET ROLE;
```

**Resultado esperado:** el `INSERT` directo falla y la funcion `crear_pedido_seguro` funciona.

**Explicacion:** se combinan permisos y funcion almacenada. El vendedor tiene permiso de ejecucion, no de escritura directa, asi que la base de datos obliga a pasar por las validaciones.

[Espacio para captura de ejecucion de la Mision 9]

---

## Mision 10 - Validar inventario con trigger

**Que se probo:** que no se pueda insertar un detalle si no hay unidades suficientes.

**Consulta de ejemplo:**

```sql
INSERT INTO pedido (id_cliente) VALUES (1);
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
VALUES ((SELECT max(id_pedido) FROM pedido), 11, 1, 275.00);
```

**Resultado esperado:** el segundo `INSERT` falla porque el producto 11 tiene cero unidades.

**Explicacion:** el trigger revisa el inventario antes de aceptar el detalle. Esto evita ventas imposibles desde cualquier ruta que intente insertar en `detalle_pedido`.

[Espacio para captura de ejecucion de la Mision 10]

---

## Mision 11 - Descontar inventario

**Que se probo:** que el inventario baje automaticamente al crear un detalle valido.

**Consulta de ejemplo:**

```sql
SELECT id_producto, nombre, unidades FROM producto WHERE id_producto = 2;
SELECT crear_pedido_seguro(1, 2, 2);
SELECT id_producto, nombre, unidades FROM producto WHERE id_producto = 2;
```

**Resultado esperado:** las unidades del producto 2 disminuyen en 2.

**Explicacion:** el trigger descuenta unidades despues de insertar el detalle. Esto mantiene el inventario actualizado sin depender de que la aplicacion recuerde hacerlo.

[Espacio para captura de ejecucion de la Mision 11]

---

## Mision 12 - Actualizar total del pedido

**Que se probo:** que el total del pedido se calcule desde sus detalles.

**Consulta de ejemplo:**

```sql
SELECT crear_pedido_seguro(1, 4, 1) AS pedido_creado;
SELECT id_pedido, total FROM pedido ORDER BY id_pedido DESC LIMIT 1;
```

**Resultado esperado:** el pedido nuevo queda con total igual a `cantidad * precio_unitario`.

**Explicacion:** el trigger actualiza `pedido.total` cada vez que se agrega un detalle. Esto evita totales escritos a mano que no coincidan con los productos vendidos.

[Espacio para captura de ejecucion de la Mision 12]

---

## Mision 13 - Auditoria de inventario

**Que se probo:** que cada cambio de unidades quede registrado.

**Consulta de ejemplo:**

```sql
SELECT crear_pedido_seguro(1, 5, 1);
SELECT * FROM auditoria_inventario ORDER BY id_auditoria DESC;
```

**Resultado esperado:** aparece un registro con `id_producto`, `unidades_antes`, `unidades_despues` y `fecha`.

**Explicacion:** el trigger guarda evidencia de los cambios de inventario. Esto ayuda a revisar que paso cuando hay diferencias o reclamos.

[Espacio para captura de ejecucion de la Mision 13]

---

## Mision 14 - Validar pago

**Que se probo:** que el pago coincida con el total del pedido.

**Consulta de ejemplo:**

```sql
SELECT crear_pedido_seguro(1, 9, 2) AS pedido_pago;

INSERT INTO pago (id_pedido, monto)
VALUES (
    (SELECT max(id_pedido) FROM pedido),
    (SELECT total FROM pedido WHERE id_pedido = (SELECT max(id_pedido) FROM pedido))
);

INSERT INTO pago (id_pedido, monto)
VALUES ((SELECT max(id_pedido) FROM pedido), 1.00);
```

**Resultado esperado:** el pago correcto se inserta y el pago incorrecto falla.

**Explicacion:** el trigger compara el monto recibido con el total del pedido antes de insertar. Esto evita registrar pagos incompletos o incorrectos como si estuvieran bien.

[Espacio para captura de ejecucion de la Mision 14]

---

## Notas finales para entrega

Antes de exportar a PDF, conviene revisar que las capturas sean legibles y que cada mision tenga su ejemplo. Tambien se debe confirmar que el archivo SQL se ejecuto completo desde cero en PostgreSQL, sin comandos de MySQL como `USE`, `AUTO_INCREMENT` o `DATETIME`.
