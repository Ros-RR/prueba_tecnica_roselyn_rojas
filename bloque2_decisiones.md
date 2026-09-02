# Bloque 2 - Modelado de Datos + Diseño de Pipeline

## 1. Objetivo del modelo

El modelo dimensional se diseña para BigQuery con el objetivo de soportar de forma consistente los análisis de Comp Sales, productividad por tienda, GMROI por proveedor y categoría, retención de clientes por cohorte, promociones y posibles quiebres de stock.

---

## 2. Modelo dimensional propuesto

### Tablas de hechos

**`fact_transaction` - grano: una fila por `transaction_id`**

Campos principales:

- `transaction_id`: identificador degenerado de la transacción.
- `date_key`, `store_key`, `customer_key`.
- `payment_method`, `loyalty_card`, `status`.
- `total_amount`.
- `gmv_net`.
- `transaction_count` = 1.
- `ingested_at`, `source_updated_at`.

Uso principal: Comp Sales, ticket promedio, transacciones por m², productividad por tienda y cohortes.

---

**`fact_sales_item` - grano: una fila por `transaction_item_id`**

Campos principales:

- `transaction_item_id`.
- `transaction_id` para trazabilidad.
- `date_key`, `store_key`, `customer_key`.
- `product_key`, `vendor_key`.
- `quantity`, `unit_price`, `was_on_promo`.
- `line_gmv`, `total_cost`, `gross_margin`.
- `data_quality_flag`.

Uso principal: GMROI, análisis de categorías, promociones, velocidad de venta y detección de posibles quiebres de stock.

---

**`fact_store_promotion` - grano: una fila por asignación tienda-promoción**

Campos principales:

- `store_key`, `promotion_key`.
- `start_date_key`, `end_date_key`.
- `variant` (`CONTROL` / `TREATMENT`).
- `assignment_valid`.
- `loaded_at`.

Esta tabla funciona como una tabla de hechos sin medidas y permite representar la asignación de promociones a tiendas.

Uso principal: análisis de experimentos y validación de conflictos entre grupos CONTROL y TREATMENT.

---

### Dimensiones

- **`dim_date`**: fecha, año, trimestre, mes, semana y atributos de calendario.
- **`dim_store`**: tienda, país, ciudad, formato, región, superficie en m² y fecha de apertura.
- **`dim_customer`**: cliente pseudonimizado, indicador de identificación, primera compra y cohorte.
- **`dim_product`**: SKU, nombre, marca, categoría, departamento y costo estándar.
- **`dim_vendor`**: proveedor, país, tier y condición de catálogo compartido.
- **`dim_promotion`**: nombre, tipo de promoción y campaña.

---

## 3. Decisiones de diseño

### 3.1 Separar transacciones e ítems en dos tablas de hechos

`total_amount` existe a nivel de transacción, mientras que cantidad, precio, producto y costo existen a nivel de ítem.

Mantener ambos granos separados evita duplicar `total_amount` cuando una transacción contiene varios productos.

`transaction_id` se conserva en `fact_sales_item` para trazabilidad, pero las agregaciones del modelo semántico no deben depender de relaciones fact-to-fact.

---

### 3.2 Manejo de transacciones sin `customer_id`

La auditoría de calidad mostró una proporción elevada de transacciones sin cliente identificado. Estas ventas continúan siendo válidas para análisis de GMV, Comp Sales y productividad, por lo que no deben eliminarse.

Se propone crear un registro especial en `dim_customer` con:

- `customer_key = -1`
- `is_identified = FALSE`

Las transacciones sin `customer_id` apuntan a esta clave.

Los análisis de cohortes y retención utilizan únicamente registros con `is_identified = TRUE`.

Esta estrategia permite conservar la totalidad de las ventas sin generar identidades artificiales de clientes.

---

### 3.3 Historial de atributos de tienda

`dim_store` se modela como una **Slowly Changing Dimension Type 2 (SCD2)** para atributos que pueden cambiar y que afectan la interpretación histórica, especialmente:

- `format`
- `region`
- `size_sqm`

Los campos `valid_from`, `valid_to` e `is_current` permiten que cada venta mantenga los atributos de la tienda que estaban vigentes en la fecha de la transacción.

---

### 3.4 Proveedores no encontrados

Si un `vendor_id` está asociado a un producto, pero no existe en la fuente de proveedores, el producto y sus ventas se conservan.

Se asigna una clave de proveedor desconocido y se mantiene el identificador natural como referencia para control de calidad.

De esta forma se evita utilizar un `INNER JOIN` que pueda eliminar ventas válidas debido a un problema de integridad referencial.

---

### 3.5 Diseño físico en BigQuery

Para optimizar costo y rendimiento:

- `fact_transaction`: partición por fecha de transacción y clustering por `store_key`, `customer_key` y `status`.
- `fact_sales_item`: partición por fecha de transacción y clustering por `store_key`, `product_key`, `vendor_key` y `customer_key`.
- Las dimensiones pequeñas se mantienen sin particionamiento.

---

# 4. Diseño del Pipeline ETL/ELT

## Flujo propuesto

`Fuentes -> Raw/Landing -> Staging -> Controles de calidad -> MERGE incremental -> Modelo dimensional -> Data Mart / Dashboard`

La capa **Raw/Landing** se conserva inmutable para garantizar trazabilidad.

Las validaciones de calidad, deduplicación y reglas de negocio se aplican en Staging antes de publicar los datos en el modelo dimensional.

---

## 4.1 Manejo de ventas con hasta 2 horas de retraso

La ingestión se ejecutaría cada hora y utilizaría un `watermark` basado en `source_updated_at` o, en ausencia de este campo, en `ingested_at`.

Debido a que las tiendas pueden reportar ventas con hasta dos horas de retraso, cada ejecución reprocesaría una ventana de seguridad de tres horas.

De esta forma, una venta tardía puede ser incorporada en una ejecución posterior sin esperar al procesamiento del día siguiente.

El `watermark` únicamente se actualizaría después de completar exitosamente la carga.

---

## 4.2 Detección automática de una tienda que dejó de enviar datos

Se mantendría una tabla de monitoreo por tienda con información como:

- última fecha y hora recibida;
- cantidad de transacciones del último lote;
- hora esperada de recepción;
- estado de la última ejecución;
- tiempo transcurrido desde el último registro recibido.

Si una tienda supera el umbral definido sin reportar información —por ejemplo, tres horas durante su ventana operativa— se genera automáticamente una alerta.

Como control adicional, el volumen recibido se compara con el comportamiento histórico de la tienda. Esto permite detectar caídas anormales incluso cuando continúan ingresando algunos registros.

De esta forma se monitorean tanto la **ausencia total de datos** como una **reducción atípica en el volumen recibido**.

---

## 4.3 Cargas incrementales sin duplicar transacciones

Las cargas se diseñan para ser idempotentes mediante operaciones `MERGE`.

Las claves naturales utilizadas son:

- `transaction_id` para `fact_transaction`;
- `transaction_item_id` para `fact_sales_item`.

Antes del `MERGE`, la capa Staging deduplica los registros y conserva la versión más reciente de cada identificador según `source_updated_at` o `ingested_at`.

Posteriormente:

- si el registro no existe, se inserta;
- si ya existe y contiene información más reciente, se actualiza;
- si no presenta cambios, no se modifica.

La ventana de reproceso de tres horas permite capturar registros tardíos y cambios de estado sin generar duplicados.

---

## 4.4 Frecuencia del pipeline para un dashboard con refresh diario

Se propone la siguiente frecuencia:

- **Ingestión Raw:** cada hora.
- **Transformaciones incrementales:** después de cada ingestión.
- **Publicación certificada del modelo:** una vez al día, antes del refresh del dashboard.
- **Dashboard:** refresh después de que la publicación diaria finalice y los controles de calidad sean satisfactorios.

Aunque el dashboard se actualice una vez al día, mantener una ingestión horaria reduce el volumen procesado en cada ejecución y permite incorporar ventas tardías de manera oportuna.

---

# 5. Gobernanza

## 5.1 Protección de `customer_id`

`customer_id` debe tratarse como un identificador sensible y no exponerse directamente en las capas de consumo analítico.

Se proponen los siguientes controles:

- pseudonimización o tokenización antes de publicar los datos en la capa analítica;
- acceso al identificador original únicamente para roles autorizados;
- controles de acceso a nivel de columna;
- vistas autorizadas para analistas;
- cifrado de la información en tránsito y en reposo;
- registro y auditoría de accesos;
- exclusión del identificador original de dashboards y exportaciones.

En BigQuery también pueden utilizarse **Policy Tags** para restringir el acceso a columnas sensibles.

Los análisis que no requieran identificar directamente al cliente utilizarían únicamente la clave pseudonimizada.

---

## 5.2 Data Owner de la tabla de transacciones

El **Data Owner** debe pertenecer al área de negocio responsable del proceso de venta, por ejemplo, la Dirección o Gerencia de Operaciones Retail/Comerciales.

La distribución de responsabilidades propuesta es:

- **Data Owner:** área de negocio responsable del significado, uso y calidad esperada del dato.
- **Data Engineering:** custodio técnico de la ingestión, procesamiento y disponibilidad.
- **Data/Analytics o Data Steward:** responsable de apoyar la estandarización de definiciones, métricas y reglas de calidad.

La propiedad del dato debe permanecer en el área de negocio y no exclusivamente en el equipo técnico.

---

## 5.3 Resolución de diferencias de GMV entre dos reportes

Si dos reportes presentan un GMV diferente para la misma tienda y el mismo día, se seguiría este proceso:

1. Confirmar que ambos reportes utilizan la misma definición de GMV.
2. Comparar filtros de fecha, zona horaria, tienda, estados de transacción y tratamiento de devoluciones.
3. Verificar si ambos reportes utilizan la misma fuente y versión de los datos.
4. Revisar posibles registros tardíos, duplicados, exclusiones por calidad y diferencias en la ejecución del pipeline.
5. Comparar los registros a nivel de `transaction_id` para localizar exactamente dónde aparece la diferencia.
6. Determinar cuál resultado corresponde al modelo o dataset certificado.
7. Corregir la causa raíz y reprocesar los datos si corresponde.
8. Documentar el incidente e implementar un control automático para evitar su recurrencia.

La definición oficial de GMV debe mantenerse en una capa semántica o catálogo de métricas certificado para garantizar que todos los reportes utilicen la misma lógica.

---

# 6. Escalabilidad y trazabilidad

El diseño separa las capas Raw, Staging y Curated, utiliza cargas incrementales idempotentes y conserva timestamps de ingestión y actualización.

Las dimensiones conformadas permiten reutilizar las mismas definiciones de tienda, fecha, cliente, producto y proveedor entre distintos análisis y dashboards.

Las excepciones identificadas durante los controles de calidad se conservan mediante `data_quality_flags` y claves `UNKNOWN`, evitando eliminar silenciosamente registros válidos para el negocio.