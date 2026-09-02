Bloque 0 - Auditoría de Calidad de Datos
================
Roselyn Rojas

- [Auditoría de Calidad de Datos](#auditoría-de-calidad-de-datos)
- [1. Completitud - `customer_id`](#1-completitud---customer_id)
- [2. Consistencia - `total_amount` vs. detalle de
  transacción](#2-consistencia---total_amount-vs-detalle-de-transacción)
- [3. Unicidad - `transaction_id`](#3-unicidad---transaction_id)
- [4. Validez](#4-validez)
  - [4.1 Validez de `total_amount`](#41-validez-de-total_amount)
  - [4.2 `unit_price = 0` sin
    promoción](#42-unit_price--0-sin-promoción)
- [5. Integridad referencial](#5-integridad-referencial)
  - [5.1 Integridad de tiendas](#51-integridad-de-tiendas)
  - [5.2 Integridad de proveedores](#52-integridad-de-proveedores)
- [6. Frescura](#6-frescura)
- [7. Integridad temporal](#7-integridad-temporal)
- [8. Validación del experimento A/B](#8-validación-del-experimento-ab)
- [9. Resumen de la auditoría](#9-resumen-de-la-auditoría)

# Auditoría de Calidad de Datos

Antes de realizar los análisis de negocio, se ejecutó una auditoría
sobre los seis archivos suministrados con el objetivo de identificar
problemas de completitud, consistencia, unicidad, validez, integridad
referencial, frescura, integridad temporal y asignación del experimento
A/B.

Para cada validación se documenta:evidencia cuantitativa,interpretación
del hallazgo,decisión aplicada y nivel de severidad.

Los archivos originales ubicados en `data/raw/` no fueron modificados
durante la auditoría.

------------------------------------------------------------------------

# 1. Completitud - `customer_id`

Se evaluó la ausencia de `customer_id` y su consistencia con el uso de
la tarjeta de lealtad (`loyalty_card`).

| Total transacciones | Sin customer_id | % sin customer_id | customer_id nulo + loyalty FALSE | customer_id nulo + loyalty TRUE | customer_id presente + loyalty FALSE | customer_id presente + loyalty TRUE |
|---:|---:|---:|---:|---:|---:|---:|
| 174,880 | 104,632 | 59.83% | 104,632 | 0 | 0 | 70,248 |

De un total de **174,880** transacciones, **104,632** (**59.83%**) no
presentan `customer_id`.

La totalidad de estos registros corresponde a transacciones con
`loyalty_card = FALSE`.

No se identificaron casos con `customer_id` nulo y
`loyalty_card = TRUE`, ni registros con `customer_id` informado y
`loyalty_card = FALSE`.

Por lo tanto, la ausencia de `customer_id` es consistente con la
definición del dataset y no se considera un error de calidad.

**Decisión:** conservar todas las transacciones para los análisis
agregados de ventas. Las transacciones sin `customer_id` se excluirán
únicamente de los análisis que requieran identificación individual del
cliente, como cohortes y retención.

**Severidad:** Informativa. No afecta las métricas agregadas de ventas,
aunque limita los análisis que requieren identificación individual del
cliente.

------------------------------------------------------------------------

# 2. Consistencia - `total_amount` vs. detalle de transacción

Se evaluó la consistencia entre el monto registrado en
`transactions.total_amount` y la suma de `quantity * unit_price` de los
artículos asociados a cada transacción.

Para evitar clasificar diferencias mínimas de representación decimal
como errores, se utilizó una tolerancia monetaria de **0.01**.

| Total transacciones | Monto consistente | Monto inconsistente | % inconsistente | Sin detalle |
|---:|---:|---:|---:|---:|
| 174,880 | 173,135 | 1,745 | 1% | 0 |

De un total de **174,880** transacciones, **173,135** presentaron
diferencias iguales o inferiores a la tolerancia definida.

Se identificaron **1,745** transacciones, equivalentes al **1%** del
total, con diferencias superiores a 0.01.

Todas las transacciones poseen registros asociados en
`transaction_items`, por lo que no se identificaron operaciones sin
detalle.

### Magnitud de las discrepancias

| Promedio | Mediana |   P75 |   P90 |   P95 |    P99 | Máximo |
|---------:|--------:|------:|------:|------:|-------:|-------:|
|     18.4 |    8.52 | 20.86 | 47.65 | 75.03 | 128.51 | 202.68 |

Entre las transacciones inconsistentes, la diferencia absoluta promedio
fue de **18.4** y la mediana de **8.52**.

La magnitud observada indica que las discrepancias no pueden atribuirse
únicamente a redondeos o diferencias menores de precisión decimal.

### Relación con el estado de la transacción

El **98.4%** de las transacciones inconsistentes corresponde a
operaciones `COMPLETED` y el **1.6%** a `RETURNED`.

Este resultado sugiere que el estado `RETURNED` no explica por sí solo
las diferencias identificadas entre el monto de cabecera y el detalle de
los artículos.

**Decisión provisional:** conservar las transacciones y marcarlas como
alerta de calidad hasta completar el análisis de la dirección de las
diferencias y su posible relación con promociones u otras reglas de
negocio. No se excluirán registros ni se sustituirá todavía
`total_amount` por el monto calculado desde el detalle.

**Severidad:** Media. La incidencia representa aproximadamente el 1% de
las transacciones, pero la magnitud de algunas diferencias puede afectar
el cálculo de GMV y otras métricas monetarias.

------------------------------------------------------------------------

# 3. Unicidad - `transaction_id`

Se evaluó la unicidad de `transaction_id`, campo definido como
identificador único de cada transacción.

| Total transacciones | ID nulos | ID duplicados | Filas involucradas | Filas excedentes |
|---:|---:|---:|---:|---:|
| 174,880 | 0 | 0 | 0 | 0 |

No se identificaron valores duplicados de `transaction_id`. Por lo
tanto, cada registro de `transactions` posee un identificador único y no
existen filas excedentes asociadas a duplicidad de la llave.

Asimismo, no se identificaron valores nulos en `transaction_id`, por lo
que el campo cumple con las condiciones esperadas para funcionar como
llave primaria de la tabla.

**Decisión:** no se requiere corrección ni deduplicación de
`transactions`. Se utilizará `transaction_id` como identificador único
para las relaciones con `transaction_items` y para los conteos de
transacciones en los análisis posteriores.

**Severidad:** Sin hallazgos. No se identificaron problemas de unicidad
en la llave principal.

------------------------------------------------------------------------

# 4. Validez

Se evaluaron valores que podrían representar condiciones económicamente
inválidas o inconsistencias en la información transaccional.

------------------------------------------------------------------------

## 4.1 Validez de `total_amount`

| Total transacciones | Monto negativo | Monto cero | % monto cero | Monto positivo |
|--------------------:|---------------:|-----------:|-------------:|---------------:|
|             174,880 |              0 |          3 |      0.0017% |        174,877 |

No se identificaron transacciones con `total_amount` negativo.

Se detectaron únicamente **3** transacciones con monto igual a cero,
equivalentes al **0.0017%** del total.

La revisión del detalle mostró que las tres operaciones corresponden a
transacciones `COMPLETED` y contienen el mismo producto, `ITEM_089`,
registrado con `unit_price = 0` y `was_on_promo = FALSE`.

En estos casos, tanto el monto de cabecera como el monto calculado desde
el detalle son iguales a cero. Por lo tanto, las transacciones son
internamente consistentes, pero presentan una anomalía desde el punto de
vista de validez económica.

Las tres operaciones se registraron en tiendas diferentes, por lo que el
patrón no se encuentra inicialmente concentrado en un único
establecimiento.

------------------------------------------------------------------------

## 4.2 `unit_price = 0` sin promoción

| Total líneas | Precio cero sin promoción | % afectado |
|-------------:|--------------------------:|-----------:|
|      542,015 |                       231 |    0.0426% |

De **542,015** líneas de transacción, **231** presentan `unit_price = 0`
y `was_on_promo = FALSE`, equivalentes al **0.0426%** del total.

La incidencia sobre el dataset completo es reducida. Sin embargo, el
análisis por producto mostró una concentración sistemática del problema.

| Producto | Nombre | Categoría | Proveedor | Costo | Casos precio cero | % de anomalías |
|:---|:---|:---|:---|---:|---:|---:|
| ITEM_089 | Bebidas Producto 89 | Bebidas | VND_027 | 7.1 | 231 | 100% |

Los registros anómalos se concentran en `ITEM_089`, correspondiente al
producto **Bebidas Producto 89**, de la categoría Bebidas y proveedor
`VND_027`.

El producto tiene un costo unitario de **7.10**, por lo que el registro
de una venta a precio cero sin una promoción explícita representa una
condición económicamente atípica.

### Comportamiento histórico de `ITEM_089`

| Total líneas | Precio cero | Precio cero sin promoción | % precio cero | Precio positivo | Precio promedio | Mediana | Precio máximo |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2,750 | 231 | 231 | 8.4% | 2,519 | 11.75 | 13.07 | 13.98 |

`ITEM_089` registra **2,750** líneas de venta durante el período.

De ellas, **2,519** presentan un precio mayor que cero y **231**
presentan precio cero sin promoción.

El precio mediano observado para el producto es **13.07**, mientras que
su costo unitario es **7.1**.

La combinación de costo positivo, comportamiento histórico de venta a
precios mayores que cero y registros puntuales a precio cero sin
promoción sugiere una anomalía sistemática asociada al registro del
precio de este SKU.

------------------------------------------------------------------------

### Relación con la consistencia de montos

Se evaluó si los registros de precio cero explican las discrepancias
detectadas entre `total_amount` y el monto calculado desde
`transaction_items`.

| Resultado           | Líneas | Porcentaje |
|:--------------------|-------:|-----------:|
| Monto inconsistente |      3 |       1.3% |
| Monto consistente   |    228 |      98.7% |

De las **231** líneas con precio cero sin promoción, **228 (98.7%)**
pertenecen a transacciones cuyo `total_amount` coincide con el monto
calculado desde el detalle.

Únicamente **3 líneas (1.3%)** se encuentran asociadas con transacciones
que también presentan una discrepancia monetaria.

Estas tres transacciones representan aproximadamente **0.17%** de las
inconsistencias monetarias identificadas en la sección anterior.

Por lo tanto, la anomalía de precio cero no explica el problema general
de conciliación entre `total_amount` y `transaction_items`. Ambos
hallazgos deben tratarse como problemas de calidad distintos.

------------------------------------------------------------------------

**Decisión:** conservar los registros en la capa original y crear una
bandera de calidad para identificar las líneas con `unit_price = 0` y
`was_on_promo = FALSE`.

No se realizará una imputación automática del precio, ya que el dataset
no proporciona una regla de negocio que permita determinar de forma
confiable cuál debió ser el precio aplicado en cada operación.

Las líneas afectadas serán tratadas separadamente en los análisis que
dependan directamente del precio del producto, principalmente margen
bruto y GMROI.

Las transacciones podrán conservarse para análisis agregados basados en
`total_amount` cuando el monto de cabecera sea válido.

Las tres transacciones con `total_amount = 0` también serán marcadas
como anómalas. Aunque existe consistencia entre cabecera y detalle,
corresponden a operaciones `COMPLETED` sobre un producto con costo
positivo vendido a precio cero sin promoción registrada.

**Severidad:** Media. La incidencia sobre el volumen total de datos es
baja, pero el patrón está concentrado sistemáticamente en un producto y
puede distorsionar métricas de precio, margen y rentabilidad a nivel
SKU.

------------------------------------------------------------------------

# 5. Integridad referencial

Se evaluó la integridad de las principales relaciones entre las tablas
transaccionales y las tablas maestras.

Las relaciones revisadas fueron:

- `transactions.store_id` → `stores.store_id`;
- `products.vendor_id` → `vendors.vendor_id`.

------------------------------------------------------------------------

## 5.1 Integridad de tiendas

| Total transacciones | Transacciones afectadas | Tiendas inexistentes | % afectado |
|--------------------:|------------------------:|---------------------:|-----------:|
|             174,880 |                       0 |                    0 |         0% |

No se identificaron transacciones asociadas a store_id inexistentes en
la tabla stores. La relación entre transactions y stores presenta
integridad referencial completa para los registros analizados.

**Decisión:** no se requiere tratamiento adicional para la relación
entre transacciones y tiendas.

**Severidad:** Sin hallazgos.

------------------------------------------------------------------------

## 5.2 Integridad de proveedores

Se validó que todos los `vendor_id` registrados en `products` existieran
en la tabla maestra `vendors`.

| Total productos | Productos afectados | Vendors inexistentes | % productos afectados |
|---:|---:|---:|---:|
| 200 | 5 | 1 | 2.5% |

Se identificaron **5 productos** cuyo `vendor_id` no tiene
correspondencia en la tabla `vendors`.

Todos los casos pertenecen al mismo identificador de proveedor,
**`VND_031`**, por lo que existe un único proveedor huérfano en la
relación.

Los productos afectados pertenecen a las categorías **Alimentos** y
**Cuidado Personal**.

### Productos afectados

| item_id | item_name | vendor_id | category | department | cost |
|:---|:---|:---|:---|:---|---:|
| ITEM_045 | Alimentos Producto 45 | VND_031 | Alimentos | Dep ALI | 10.24 |
| ITEM_078 | Cuidado Personal Producto 78 | VND_031 | Cuidado Personal | Dep CUI | 7.46 |
| ITEM_112 | Cuidado Personal Producto 112 | VND_031 | Cuidado Personal | Dep CUI | 7.02 |
| ITEM_156 | Alimentos Producto 156 | VND_031 | Alimentos | Dep ALI | 4.21 |
| ITEM_189 | Alimentos Producto 189 | VND_031 | Alimentos | Dep ALI | 6.79 |

Aunque el problema afecta únicamente cinco registros de la dimensión de
productos, su relevancia aumenta al considerar su presencia en las
ventas.

### Impacto transaccional

| Líneas afectadas | % líneas | Transacciones afectadas | % transacciones | Unidades | GMV detalle |
|---:|---:|---:|---:|---:|---:|
| 13,474 | 2.49% | 13,039 | 7.46% | 21,495 | 246,568.4 |

Los cinco productos asociados a `VND_031` participan en **13,039**
transacciones, equivalentes al **7.46%** del total.

Además, representan **13,474** líneas de venta (**2.49%** del detalle),
**21,495** unidades y un GMV calculado desde el detalle de
aproximadamente **246,568.4**.

Por lo tanto, aunque la inconsistencia afecta una cantidad reducida de
productos, su impacto transaccional es material.

**Decisión:** conservar los cinco productos y sus ventas. Se mantendrá
`VND_031` como identificador del proveedor y se creará una bandera de
integridad referencial para identificar que el proveedor no fue
encontrado en la tabla maestra.

Cuando un análisis requiera atributos provenientes de `vendors`, como
nombre, país, tier o disponibilidad en catálogo compartido, `VND_031` se
clasificará como `VENDOR_NO_ENCONTRADO` hasta disponer de una corrección
de la tabla maestra.

Para los análisis de GMROI se conservarán las ventas, costos, unidades y
categorías correspondientes a estos productos. Se evitarán uniones
internas que eliminen los registros por falta de correspondencia en
`vendors`.

**Severidad:** Media-Alta. La inconsistencia afecta únicamente cinco
productos, pero estos participan en aproximadamente **7.46%** de las
transacciones. Una unión incorrecta con la dimensión `vendors` podría
excluir una fracción material de las ventas y sesgar los análisis de
rentabilidad por proveedor.

La principal anomalía de integridad referencial identificada corresponde
a productos asociados al proveedor `VND_031`, inexistente en la tabla
maestra `vendors`.

El tratamiento definido prioriza conservar las ventas y mantener
trazabilidad, evitando eliminar registros válidos por una deficiencia en
la dimensión de proveedores.

------------------------------------------------------------------------

# 6. Frescura

Se evaluaron períodos consecutivos sin transacciones por tienda,
considerando como relevantes los gaps de **3 o más días**.

| Gaps detectados | Tiendas con gap | Gap máximo (días) | Gaps \>= 3 días |
|----------------:|----------------:|------------------:|----------------:|
|               1 |               1 |                 7 |               1 |

Se identificó un único gap de **7 días consecutivos** en `TIENDA_012`
(Tienda Escuintla 12), entre el **10 y el 16 de septiembre de 2024**.

| Período        | Días | Días con ventas | Transacciones | Promedio diario |
|:---------------|-----:|----------------:|--------------:|----------------:|
| 7 días antes   |    7 |               7 |            58 |            8.29 |
| 7 días después |    7 |               7 |            49 |            7.00 |
| Gap            |    7 |               0 |             0 |            0.00 |

La tienda registró actividad todos los días durante la semana anterior
(58 transacciones) y posterior (49 transacciones), mientras que durante
el gap no registró ninguna operación.

El patrón es atípico; sin embargo, los datos no permiten determinar si
corresponde a un cierre real de la tienda o a una interrupción en el
reporte de información.

**Decisión:** conservar los datos sin imputar ventas y marcar el período
como alerta de frescura. No se interpretará automáticamente como una
caída de demanda.

**Severidad:** Media. El hallazgo afecta una sola tienda, pero puede
distorsionar métricas semanales y análisis de estacionalidad.

------------------------------------------------------------------------

# 7. Integridad temporal

Se validó que las transacciones fueran registradas en fechas iguales o
posteriores a la fecha de apertura (`opening_date`) de cada tienda.

| Transacciones afectadas | Tiendas afectadas |
|------------------------:|------------------:|
|                      50 |                 1 |

Se identificaron **50 transacciones** anteriores a la fecha oficial de
apertura, concentradas en una única tienda.

| Tienda | Nombre | Fecha apertura | Transacciones afectadas | Primera transacción | Última transacción | Máximo días antes |
|:---|:---|:---|---:|:---|:---|---:|
| TIENDA_037 | Tienda Quetzaltenango 37 | 2024-06-01 | 50 | 2024-05-15 | 2024-05-31 | 17 |

El hallazgo corresponde a `TIENDA_037` (Tienda Quetzaltenango 37), cuya
fecha de apertura registrada es el **1 de junio de 2024**.

Sin embargo, existen 50 transacciones entre el **15 y el 31 de mayo de
2024**, con un desfase máximo de **17 días antes de la apertura**.

Los datos disponibles no permiten determinar si estas operaciones
corresponden a actividades de preapertura o a una inconsistencia en la
fecha maestra de la tienda.

**Decisión:** conservar los registros en la capa original y marcarlos
como alerta de integridad temporal. Las 50 transacciones se excluirán de
análisis que requieran respetar el período oficial de operación de la
tienda, como Comp Sales y productividad, mientras no exista evidencia
que justifique corregir `opening_date`.

**Severidad:** Media. El problema afecta una sola tienda y un número
reducido de transacciones, pero puede distorsionar métricas basadas en
antigüedad y períodos comparables.

------------------------------------------------------------------------

# 8. Validación del experimento A/B

Se evaluó si alguna tienda fue asignada simultáneamente a `CONTROL` y
`TREATMENT` dentro del mismo experimento y durante períodos
superpuestos.

| Conflictos detectados | Tiendas afectadas | Promociones afectadas |
|----------------------:|------------------:|----------------------:|
|                     2 |                 2 |                     1 |

Se identificaron **2 conflictos**, correspondientes a **2 tiendas**
dentro de la promoción `Exhibicion_Q3_2024`.

| Tienda | Nombre | País | Formato | Tamaño m2 | Inicio CONTROL | Fin CONTROL | Inicio TREATMENT | Fin TREATMENT |
|:---|:---|:---|:---|---:|:---|:---|:---|:---|
| TIENDA_008 | Tienda San Pedro Sula 8 | HN | HIPERMERCADO | 4881 | 2024-09-01 | 2024-10-12 | 2024-09-01 | 2024-10-12 |
| TIENDA_037 | Tienda Quetzaltenango 37 | GT | EXPRESS | 257 | 2024-09-01 | 2024-10-12 | 2024-09-01 | 2024-10-12 |

Las tiendas `TIENDA_008` y `TIENDA_037` aparecen asignadas a ambas
variantes durante todo el período comprendido entre el **1 de septiembre
y el 12 de octubre de 2024**.

Esta condición genera contaminación experimental y no permite determinar
de forma confiable a qué grupo pertenece cada establecimiento.

**Decisión:** conservar los registros originales, pero excluir ambas
tiendas del análisis principal del experimento A/B. No se realizará una
reasignación arbitraria a CONTROL o TREATMENT.

**Severidad:** Alta para el análisis experimental. Aunque únicamente
afecta dos tiendas, su inclusión comprometería la independencia entre
los grupos y podría sesgar la estimación del efecto de la estrategia de
exhibición.

------------------------------------------------------------------------

# 9. Resumen de la auditoría

La siguiente tabla consolida los principales hallazgos identificados
durante la auditoría y el tratamiento definido para los análisis
posteriores.

| Dimensión | Hallazgo | Evidencia | Decisión | Severidad |
|:---|:---|:---|:---|:---|
| Completitud | 59.83% de transacciones sin customer_id, consistente con loyalty_card = FALSE. | 104,632 de 174,880 transacciones; 0 inconsistencias con loyalty_card. | Conservar. Excluir únicamente de cohortes y análisis que requieran identificación de cliente. | Informativa |
| Consistencia | 1,745 transacciones presentan diferencias entre total_amount y el detalle. | 1% del total; mediana de diferencia = 8.52; máximo = 202.68. | Conservar y marcar como alerta. No sustituir montos hasta definir la fuente monetaria oficial. | Media |
| Unicidad | No se identificaron transaction_id duplicados. | 0 IDs duplicados y 0 filas excedentes. | Sin tratamiento. Utilizar transaction_id como identificador único. | Sin hallazgos |
| Validez | 3 transacciones con total_amount = 0 y 231 líneas con unit_price = 0 sin promoción, concentradas en ITEM_089. | 0.0426% de las líneas. ITEM_089 tiene costo 7.10 y mediana de precio 13.10. | Conservar en raw y marcar anomalías. No imputar precios; tratar por separado en margen y GMROI. | Media |
| Integridad referencial | Sin problemas en store_id. 5 productos están asociados al vendor inexistente VND_031. | 13,039 transacciones afectadas (7.46% del total). | Conservar ventas. Mantener VND_031 como proveedor no encontrado y evitar INNER JOIN que elimine operaciones. | Media-Alta |
| Frescura | Un gap de 7 días consecutivos sin transacciones en TIENDA_012. | TIENDA_012: 58 transacciones en los 7 días previos, 0 durante el gap y 49 en los 7 días posteriores. | Conservar sin imputar ventas. Marcar 2024-09-10 a 2024-09-16 como alerta de frescura. | Media |
| Integridad temporal | 50 transacciones de TIENDA_037 registradas antes de opening_date. | TIENDA_037: ventas entre 2024-05-15 y 2024-05-31; máximo 17 días antes de la apertura. | Conservar y marcar alerta. Excluir estas operaciones de análisis sujetos a la fecha oficial de apertura. | Media |
| A/B Test | 2 tiendas asignadas simultáneamente a CONTROL y TREATMENT. | TIENDA_008 y TIENDA_037 aparecen en ambas variantes durante todo el período 2024-09-01 a 2024-10-12. | Excluir TIENDA_008 y TIENDA_037 del análisis principal del experimento A/B. | Alta |

La auditoría evidencia una calidad general adecuada para continuar con
los análisis, aunque se identificaron anomalías puntuales que requieren
controles específicos.

Los principales riesgos corresponden a la inconsistencia entre
`total_amount` y el detalle de algunas transacciones, la ausencia del
proveedor `VND_031` en la tabla maestra y la asignación conflictiva de
dos tiendas dentro del experimento A/B.

No se modificaron los archivos originales. Los tratamientos definidos se
aplicarán posteriormente mediante reglas de exclusión, banderas de
calidad o clasificaciones explícitas, según corresponda.
