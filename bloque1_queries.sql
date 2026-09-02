-- ============================================================
-- BLOQUE 1 - SQL AVANZADO
-- ============================================================
-- Motor utilizado para validación: DuckDB
--
-- Requisitos para reproducir las consultas:
--   1. Restaurar las dependencias de R con renv::restore().
--   2. Ejecutar previamente R/03_carga_sql.R.
--   3. El proceso anterior crea las tablas:
--        - transactions
--        - transaction_items
--        - stores
--        - products
--        - vendors
--        - store_promotions
--
-- Cada query es independiente y puede ejecutarse por separado.
--
-- Criterios generales:
--   - COMPLETED suma al GMV.
--   - RETURNED resta al GMV cuando corresponde.
--   - Las reglas de calidad utilizadas provienen del Bloque 0.
-- ============================================================



-- ============================================================
-- QUERY 1 - VENTAS COMPARABLES (COMP SALES)
-- ============================================================
-- Calcular el crecimiento YoY únicamente para tiendas
-- comparables, es decir, tiendas operativas durante todo el
-- período actual y el período equivalente del año anterior.
-- ============================================================

WITH parametros AS (

    SELECT
        MAX(transaction_date) AS fecha_maxima,

        CAST(
            DATE_TRUNC('year', MAX(transaction_date))
            AS DATE
        ) AS inicio_actual,

        CAST(
            DATE_TRUNC('year', MAX(transaction_date))
            - INTERVAL '1 year'
            AS DATE
        ) AS inicio_anterior,

        CAST(
            MAX(transaction_date)
            - INTERVAL '1 year'
            AS DATE
        ) AS fin_anterior

    FROM transactions
),


-- TIENDAS COMPARABLES

tiendas_comparables AS (

    SELECT
        s.store_id,
        s.store_name,
        s.country,
        s.format,
        s.opening_date

    FROM stores AS s

    CROSS JOIN parametros AS p

    WHERE
        s.opening_date <= p.inicio_anterior
),


-- TRANSACCIONES DE LOS DOS PERÍODOS

ventas_base AS (

    SELECT
        t.transaction_id,
        t.store_id,
        t.transaction_date,

        CASE
            WHEN t.status = 'COMPLETED'
                THEN t.total_amount

            WHEN t.status = 'RETURNED'
                THEN -t.total_amount

            ELSE 0
        END AS gmv_neto,

        CASE
            WHEN t.transaction_date
                 BETWEEN p.inicio_actual AND p.fecha_maxima
                THEN 'ACTUAL'

            WHEN t.transaction_date
                 BETWEEN p.inicio_anterior AND p.fin_anterior
                THEN 'ANTERIOR'

            ELSE NULL
        END AS periodo

    FROM transactions AS t

    INNER JOIN tiendas_comparables AS s
        ON t.store_id = s.store_id

    CROSS JOIN parametros AS p

    WHERE
        t.transaction_date
            BETWEEN p.inicio_anterior AND p.fecha_maxima

        AND (
            t.transaction_date <= p.fin_anterior
            OR
            t.transaction_date >= p.inicio_actual
        )
),


-- GMV POR TIENDA

gmv_tienda AS (

    SELECT
        store_id,

        SUM(
            CASE
                WHEN periodo = 'ANTERIOR'
                    THEN gmv_neto
                ELSE 0
            END
        ) AS gmv_anio_anterior,

        SUM(
            CASE
                WHEN periodo = 'ACTUAL'
                    THEN gmv_neto
                ELSE 0
            END
        ) AS gmv_anio_actual,

        SUM(
            CASE
                WHEN periodo = 'ANTERIOR'
                    THEN 1
                ELSE 0
            END
        ) AS transacciones_anterior,

        SUM(
            CASE
                WHEN periodo = 'ACTUAL'
                    THEN 1
                ELSE 0
            END
        ) AS transacciones_actual

    FROM ventas_base

    GROUP BY
        store_id
),


-- CÁLCULO DE COMP SALES POR TIENDA

comp_tienda AS (

    SELECT
        s.country,
        s.format,
        s.store_id,
        s.store_name,
        s.opening_date,

        g.gmv_anio_anterior,
        g.gmv_anio_actual,

        100.0 *
        (
            g.gmv_anio_actual - g.gmv_anio_anterior
        )
        /
        NULLIF(
            g.gmv_anio_anterior,
            0
        ) AS comp_sales_growth_pct

    FROM gmv_tienda AS g

    INNER JOIN tiendas_comparables AS s
        ON g.store_id = s.store_id

    WHERE
        g.transacciones_anterior > 0
        AND g.transacciones_actual > 0
),


-- RANKING Y MÉTRICAS POR PAÍS / FORMATO

resultado AS (

    SELECT
        country,
        format,
        store_id,
        store_name,
        opening_date,

        gmv_anio_anterior,
        gmv_anio_actual,
        comp_sales_growth_pct,

        RANK() OVER (
            PARTITION BY
                country,
                format
            ORDER BY
                comp_sales_growth_pct DESC
        ) AS ranking_crecimiento,

        SUM(gmv_anio_anterior) OVER (
            PARTITION BY
                country,
                format
        ) AS gmv_formato_anterior,

        SUM(gmv_anio_actual) OVER (
            PARTITION BY
                country,
                format
        ) AS gmv_formato_actual

    FROM comp_tienda
)


-- RESULTADO FINAL

SELECT
    country,
    format,
    store_id,
    store_name,
    opening_date,

    ROUND(
        gmv_anio_anterior,
        2
    ) AS gmv_anio_anterior,

    ROUND(
        gmv_anio_actual,
        2
    ) AS gmv_anio_actual,

    ROUND(
        comp_sales_growth_pct,
        2
    ) AS comp_sales_growth_pct,

    ranking_crecimiento,

    ROUND(
        gmv_formato_anterior,
        2
    ) AS gmv_pais_formato_anterior,

    ROUND(
        gmv_formato_actual,
        2
    ) AS gmv_pais_formato_actual,

    ROUND(
        100.0 *
        (
            gmv_formato_actual -
            gmv_formato_anterior
        )
        /
        NULLIF(
            gmv_formato_anterior,
            0
        ),
        2
    ) AS comp_sales_pais_formato_pct

FROM resultado

ORDER BY
    country,
    format,
    ranking_crecimiento;



-- ============================================================
-- QUERY 2 - PRODUCTIVIDAD POR METRO CUADRADO
-- ============================================================
-- Calcular productividad operativa por tienda durante el
-- último trimestre calendario disponible.
--
-- Métricas:
--   - GMV neto
--   - GMV por m2
--   - Transacciones por m2
--   - Ticket promedio
--   - Ranking dentro del formato
--   - Identificación de tiendas bajo el percentil 25
--
-- COMPLETED suma al GMV.
-- RETURNED resta al GMV.
-- ============================================================

WITH parametros AS (

    SELECT
        MAX(transaction_date) AS fecha_maxima,

        CAST(
            DATE_TRUNC('quarter', MAX(transaction_date))
            AS DATE
        ) AS inicio_trimestre,

        CAST(
            DATE_TRUNC('quarter', MAX(transaction_date))
            + INTERVAL '3 months'
            - INTERVAL '1 day'
            AS DATE
        ) AS fin_trimestre

    FROM transactions
),


-- MÉTRICAS POR TIENDA

metricas_tienda AS (

    SELECT
        s.store_id,
        s.store_name,
        s.country,
        s.format,
        s.region,
        s.size_sqm,

        SUM(
            CASE
                WHEN t.status = 'COMPLETED'
                    THEN t.total_amount

                WHEN t.status = 'RETURNED'
                    THEN -t.total_amount

                ELSE 0
            END
        ) AS gmv_neto,

        COUNT(DISTINCT t.transaction_id)
            AS numero_transacciones

    FROM transactions AS t

    INNER JOIN stores AS s
        ON t.store_id = s.store_id

    CROSS JOIN parametros AS p

    WHERE
        t.transaction_date
            BETWEEN p.inicio_trimestre
            AND p.fin_trimestre

    GROUP BY
        s.store_id,
        s.store_name,
        s.country,
        s.format,
        s.region,
        s.size_sqm
),


-- PRODUCTIVIDAD

productividad AS (

    SELECT
        store_id,
        store_name,
        country,
        format,
        region,
        size_sqm,
        gmv_neto,
        numero_transacciones,

        gmv_neto /
            NULLIF(size_sqm, 0)
            AS gmv_por_m2,

        numero_transacciones * 1.0 /
            NULLIF(size_sqm, 0)
            AS transacciones_por_m2,

        gmv_neto /
            NULLIF(numero_transacciones, 0)
            AS ticket_promedio

    FROM metricas_tienda
),


-- PERCENTIL 25 POR FORMATO

percentiles AS (

    SELECT
        *,

        QUANTILE_CONT(
            gmv_por_m2,
            0.25
        ) OVER (
            PARTITION BY format
        ) AS percentil_25_gmv_m2

    FROM productividad
),


-- RANKING

resultado AS (

    SELECT
        *,

        RANK() OVER (
            PARTITION BY format
            ORDER BY gmv_por_m2 DESC
        ) AS ranking_formato

    FROM percentiles
)


-- RESULTADO FINAL

SELECT
    store_id,
    store_name,
    country,
    format,
    region,
    size_sqm,

    ROUND(
        gmv_neto,
        2
    ) AS gmv_trimestre,

    numero_transacciones,

    ROUND(
        gmv_por_m2,
        2
    ) AS gmv_por_m2,

    ROUND(
        transacciones_por_m2,
        4
    ) AS transacciones_por_m2,

    ROUND(
        ticket_promedio,
        2
    ) AS ticket_promedio,

    ROUND(
        percentil_25_gmv_m2,
        2
    ) AS percentil_25_gmv_m2,

    ranking_formato,

    CASE
        WHEN gmv_por_m2 < percentil_25_gmv_m2
            THEN 'BAJO_RENDIMIENTO'

        ELSE 'NORMAL'
    END AS estado_rendimiento

FROM resultado

ORDER BY
    format,
    ranking_formato;



-- ============================================================
-- QUERY 3 - ANÁLISIS DE COHORTES DE CLIENTES CON LEALTAD
-- ============================================================
-- Medir la retención de clientes identificados según el mes
-- de su primera compra.
--
-- Solo clientes con loyalty_card = TRUE y customer_id válido.
-- Solo transacciones COMPLETED para definir compra/retención.
-- Cohorte = mes de primera compra.
-- Retención medida en M1, M2, M3 y M6.
--
-- Un período observable sin clientes retenidos se reporta 0%.
-- Un período todavía no observable se reporta como NULL.
-- ============================================================

WITH parametros AS (

    SELECT
        DATE_TRUNC(
            'month',
            MAX(transaction_date)
        ) AS ultimo_mes_observable

    FROM transactions
),


-- TRANSACCIONES DE CLIENTES IDENTIFICADOS

ventas_lealtad AS (

    SELECT
        transaction_id,
        customer_id,
        transaction_date,

        DATE_TRUNC(
            'month',
            transaction_date
        ) AS mes_transaccion,

        total_amount

    FROM transactions

    WHERE
        loyalty_card = TRUE
        AND customer_id IS NOT NULL
        AND status = 'COMPLETED'
),


-- PRIMERA COMPRA Y COHORTE DE CADA CLIENTE

cohortes_cliente AS (

    SELECT
        customer_id,

        MIN(mes_transaccion)
            AS mes_cohorte

    FROM ventas_lealtad

    GROUP BY
        customer_id
),


-- ACTIVIDAD DEL CLIENTE POR MES

actividad_cliente_mes AS (

    SELECT
        v.customer_id,
        c.mes_cohorte,
        v.mes_transaccion,

        DATE_DIFF(
            'month',
            c.mes_cohorte,
            v.mes_transaccion
        ) AS mes_desde_cohorte,

        COUNT(DISTINCT v.transaction_id)
            AS transacciones,

        SUM(v.total_amount)
            AS gmv,

        SUM(v.total_amount)
        /
        NULLIF(
            COUNT(DISTINCT v.transaction_id),
            0
        ) AS ticket_promedio_cliente_mes

    FROM ventas_lealtad AS v

    INNER JOIN cohortes_cliente AS c
        ON v.customer_id = c.customer_id

    GROUP BY
        v.customer_id,
        c.mes_cohorte,
        v.mes_transaccion
),


-- TAMAÑO DE COHORTE

tamano_cohorte AS (

    SELECT
        mes_cohorte,

        COUNT(DISTINCT customer_id)
            AS tamano_cohorte

    FROM cohortes_cliente

    GROUP BY
        mes_cohorte
),


-- MÉTRICAS POR COHORTE Y MES

metricas_cohorte AS (

    SELECT
        mes_cohorte,
        mes_desde_cohorte,

        COUNT(DISTINCT customer_id)
            AS clientes_activos,

        SUM(gmv)
        /
        NULLIF(
            SUM(transacciones),
            0
        ) AS ticket_promedio

    FROM actividad_cliente_mes

    WHERE
        mes_desde_cohorte IN (0, 1, 2, 3, 6)

    GROUP BY
        mes_cohorte,
        mes_desde_cohorte
),


-- PIVOT DE RETENCIÓN Y TICKET

resultado AS (

    SELECT
        t.mes_cohorte,
        t.tamano_cohorte,

        MAX(
            CASE
                WHEN m.mes_desde_cohorte = 0
                    THEN m.ticket_promedio
            END
        ) AS ticket_m0,


        -- RETENCIÓN M1

        CASE
            WHEN t.mes_cohorte + INTERVAL '1 month'
                 <= p.ultimo_mes_observable
            THEN
                100.0 *
                COALESCE(
                    MAX(
                        CASE
                            WHEN m.mes_desde_cohorte = 1
                                THEN m.clientes_activos
                        END
                    ),
                    0
                )
                /
                NULLIF(t.tamano_cohorte, 0)
        END AS retencion_m1_pct,

        MAX(
            CASE
                WHEN m.mes_desde_cohorte = 1
                    THEN m.ticket_promedio
            END
        ) AS ticket_m1,


        -- RETENCIÓN M2

        CASE
            WHEN t.mes_cohorte + INTERVAL '2 months'
                 <= p.ultimo_mes_observable
            THEN
                100.0 *
                COALESCE(
                    MAX(
                        CASE
                            WHEN m.mes_desde_cohorte = 2
                                THEN m.clientes_activos
                        END
                    ),
                    0
                )
                /
                NULLIF(t.tamano_cohorte, 0)
        END AS retencion_m2_pct,

        MAX(
            CASE
                WHEN m.mes_desde_cohorte = 2
                    THEN m.ticket_promedio
            END
        ) AS ticket_m2,


        -- RETENCIÓN M3

        CASE
            WHEN t.mes_cohorte + INTERVAL '3 months'
                 <= p.ultimo_mes_observable
            THEN
                100.0 *
                COALESCE(
                    MAX(
                        CASE
                            WHEN m.mes_desde_cohorte = 3
                                THEN m.clientes_activos
                        END
                    ),
                    0
                )
                /
                NULLIF(t.tamano_cohorte, 0)
        END AS retencion_m3_pct,

        MAX(
            CASE
                WHEN m.mes_desde_cohorte = 3
                    THEN m.ticket_promedio
            END
        ) AS ticket_m3,


        -- RETENCIÓN M6

        CASE
            WHEN t.mes_cohorte + INTERVAL '6 months'
                 <= p.ultimo_mes_observable
            THEN
                100.0 *
                COALESCE(
                    MAX(
                        CASE
                            WHEN m.mes_desde_cohorte = 6
                                THEN m.clientes_activos
                        END
                    ),
                    0
                )
                /
                NULLIF(t.tamano_cohorte, 0)
        END AS retencion_m6_pct,

        MAX(
            CASE
                WHEN m.mes_desde_cohorte = 6
                    THEN m.ticket_promedio
            END
        ) AS ticket_m6

    FROM tamano_cohorte AS t

    LEFT JOIN metricas_cohorte AS m
        ON t.mes_cohorte = m.mes_cohorte

    CROSS JOIN parametros AS p

    GROUP BY
        t.mes_cohorte,
        t.tamano_cohorte,
        p.ultimo_mes_observable
)


-- RESULTADO FINAL

SELECT
    mes_cohorte,
    tamano_cohorte,

    ROUND(ticket_m0, 2)
        AS ticket_m0,

    ROUND(retencion_m1_pct, 2)
        AS retencion_m1_pct,

    ROUND(ticket_m1, 2)
        AS ticket_m1,

    ROUND(retencion_m2_pct, 2)
        AS retencion_m2_pct,

    ROUND(ticket_m2, 2)
        AS ticket_m2,

    ROUND(retencion_m3_pct, 2)
        AS retencion_m3_pct,

    ROUND(ticket_m3, 2)
        AS ticket_m3,

    ROUND(retencion_m6_pct, 2)
        AS retencion_m6_pct,

    ROUND(ticket_m6, 2)
        AS ticket_m6,

    CASE
        WHEN ticket_m6 IS NOT NULL
             AND ticket_m6 > ticket_m0
            THEN 'CRECE'

        WHEN ticket_m6 IS NOT NULL
             AND ticket_m6 < ticket_m0
            THEN 'DECRECE'

        WHEN ticket_m6 IS NOT NULL
            THEN 'ESTABLE'

        ELSE 'NO_OBSERVABLE'
    END AS tendencia_ticket_m6

FROM resultado

ORDER BY
    mes_cohorte;



-- ============================================================
-- QUERY 4 - GMROI POR PROVEEDOR Y CATEGORÍA
-- ============================================================
-- Evaluar la rentabilidad por combinación de proveedor
-- y categoría.
--
-- Métricas:
--   - GMV neto calculado desde transaction_items
--   - Costo total
--   - Margen bruto
--   - GMROI = Margen bruto / Costo total
--   - SKUs activos
--   - Velocidad de venta (unidades/día)
--
-- COMPLETED suma ventas, unidades y costo.
-- RETURNED revierte ventas, unidades y costo.
-- Se conservan productos asociados a vendors inexistentes.
-- VND_031 se clasifica como VENDOR_NO_ENCONTRADO.
-- Se excluyen del cálculo principal las líneas con
-- unit_price = 0 y was_on_promo = FALSE.
-- ============================================================

WITH parametros AS (

    SELECT
        MIN(transaction_date) AS fecha_minima,
        MAX(transaction_date) AS fecha_maxima,

        DATE_DIFF(
            'day',
            MIN(transaction_date),
            MAX(transaction_date)
        ) + 1 AS dias_periodo

    FROM transactions
),


-- BASE DE VENTAS A NIVEL ITEM

ventas_base AS (

    SELECT
        t.transaction_id,
        t.transaction_date,
        t.status,

        ti.item_id,
        ti.quantity,
        ti.unit_price,
        ti.was_on_promo,

        p.vendor_id,
        p.category,
        p.cost,

        COALESCE(
            v.vendor_name,
            'VENDOR_NO_ENCONTRADO'
        ) AS vendor_name,

        CASE
            WHEN t.status = 'COMPLETED'
                THEN ti.quantity * ti.unit_price

            WHEN t.status = 'RETURNED'
                THEN -(ti.quantity * ti.unit_price)

            ELSE 0
        END AS gmv_neto,

        CASE
            WHEN t.status = 'COMPLETED'
                THEN ti.quantity * p.cost

            WHEN t.status = 'RETURNED'
                THEN -(ti.quantity * p.cost)

            ELSE 0
        END AS costo_total,

        CASE
            WHEN t.status = 'COMPLETED'
                THEN ti.quantity

            WHEN t.status = 'RETURNED'
                THEN -ti.quantity

            ELSE 0
        END AS unidades_netas

    FROM transaction_items AS ti

    INNER JOIN transactions AS t
        ON ti.transaction_id = t.transaction_id

    INNER JOIN products AS p
        ON ti.item_id = p.item_id

    LEFT JOIN vendors AS v
        ON p.vendor_id = v.vendor_id

    WHERE
        t.status IN ('COMPLETED', 'RETURNED')

        AND NOT (
            ti.unit_price = 0
            AND ti.was_on_promo = FALSE
        )
),


-- AGREGACIÓN POR PROVEEDOR Y CATEGORÍA

metricas_vendor_categoria AS (

    SELECT
        vendor_id,
        vendor_name,
        category,

        SUM(gmv_neto)
            AS gmv,

        SUM(costo_total)
            AS costo_total,

        SUM(gmv_neto) -
        SUM(costo_total)
            AS margen_bruto,

        COUNT(DISTINCT item_id)
            AS skus_activos,

        SUM(unidades_netas)
            AS unidades_netas

    FROM ventas_base

    GROUP BY
        vendor_id,
        vendor_name,
        category
),


-- CÁLCULO DE GMROI Y VELOCIDAD DE VENTA

resultado AS (

    SELECT
        m.vendor_id,
        m.vendor_name,
        m.category,

        m.gmv,
        m.costo_total,
        m.margen_bruto,
        m.skus_activos,
        m.unidades_netas,

        m.margen_bruto /
            NULLIF(m.costo_total, 0)
            AS gmroi,

        m.unidades_netas * 1.0 /
            NULLIF(p.dias_periodo, 0)
            AS velocidad_venta_unidades_dia

    FROM metricas_vendor_categoria AS m

    CROSS JOIN parametros AS p
)


-- RESULTADO FINAL

SELECT
    vendor_id,
    vendor_name,
    category,

    ROUND(
        gmv,
        2
    ) AS gmv,

    ROUND(
        costo_total,
        2
    ) AS costo_total,

    ROUND(
        margen_bruto,
        2
    ) AS margen_bruto,

    ROUND(
        gmroi,
        4
    ) AS gmroi,

    skus_activos,

    unidades_netas,

    ROUND(
        velocidad_venta_unidades_dia,
        2
    ) AS velocidad_venta_unidades_dia,

    CASE
        WHEN costo_total <= 0
            THEN 'NO_CALCULABLE'

        WHEN gmroi < 1
            THEN 'GMROI_BAJO'

        ELSE 'GMROI_ADECUADO'
    END AS estado_gmroi

FROM resultado

ORDER BY
    gmroi ASC,
    vendor_id,
    category;



-- ============================================================
-- QUERY 5 - DETECCIÓN DE POSIBLES QUIEBRES DE STOCK
-- ============================================================
-- Identificar productos con 3 o más días consecutivos sin
-- ventas dentro de una tienda donde históricamente sí se
-- registraban ventas.
--
-- Solo transacciones COMPLETED representan ventas.
-- Se analiza cada combinación store_id + item_id.
-- El calendario inicia en la primera venta y termina en
-- la última venta observada del producto en esa tienda.
-- Se consideran posibles quiebres los gaps >= 3 días.
-- La demanda histórica se estima con los 28 días
-- calendario anteriores al inicio del gap.
--
-- GMV perdido estimado =
-- GMV promedio diario previo * duración del gap.
--
-- El resultado representa posibles quiebres inferidos por
-- ausencia de ventas; no confirma disponibilidad física.
-- ============================================================

WITH ventas_diarias AS (

    SELECT
        t.store_id,
        ti.item_id,
        t.transaction_date,

        SUM(ti.quantity)
            AS unidades_vendidas,

        SUM(
            CASE
                WHEN NOT (
                    ti.unit_price = 0
                    AND ti.was_on_promo = FALSE
                )
                THEN ti.quantity * ti.unit_price

                ELSE 0
            END
        ) AS gmv_dia

    FROM transaction_items AS ti

    INNER JOIN transactions AS t
        ON ti.transaction_id = t.transaction_id

    WHERE
        t.status = 'COMPLETED'

    GROUP BY
        t.store_id,
        ti.item_id,
        t.transaction_date
),


-- RANGO HISTÓRICO DE VENTA POR TIENDA / ITEM

rango_producto_tienda AS (

    SELECT
        store_id,
        item_id,

        MIN(transaction_date)
            AS primera_venta,

        MAX(transaction_date)
            AS ultima_venta

    FROM ventas_diarias

    WHERE
        unidades_vendidas > 0

    GROUP BY
        store_id,
        item_id
),


-- GENERAR CALENDARIO DIARIO

calendario AS (

    SELECT
        r.store_id,
        r.item_id,

        CAST(gs.fecha AS DATE)
            AS transaction_date

    FROM rango_producto_tienda AS r

    CROSS JOIN generate_series(
        r.primera_venta,
        r.ultima_venta,
        INTERVAL '1 day'
    ) AS gs(fecha)
),


-- COMPLETAR DÍAS SIN VENTA CON CERO

serie_diaria AS (

    SELECT
        c.store_id,
        c.item_id,
        c.transaction_date,

        COALESCE(
            v.unidades_vendidas,
            0
        ) AS unidades_vendidas,

        COALESCE(
            v.gmv_dia,
            0
        ) AS gmv_dia

    FROM calendario AS c

    LEFT JOIN ventas_diarias AS v
        ON c.store_id = v.store_id
       AND c.item_id = v.item_id
       AND c.transaction_date = v.transaction_date
),


-- IDENTIFICAR SECUENCIAS CONSECUTIVAS SIN VENTAS

serie_con_grupo AS (

    SELECT
        *,

        SUM(
            CASE
                WHEN unidades_vendidas > 0
                    THEN 1

                ELSE 0
            END
        ) OVER (
            PARTITION BY
                store_id,
                item_id

            ORDER BY
                transaction_date

            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS grupo_gap

    FROM serie_diaria
),


-- RESUMIR LOS GAPS

gaps AS (

    SELECT
        store_id,
        item_id,
        grupo_gap,

        MIN(transaction_date)
            AS fecha_inicio_gap,

        MAX(transaction_date)
            AS fecha_fin_gap,

        COUNT(*)
            AS dias_gap

    FROM serie_con_grupo

    WHERE
        unidades_vendidas = 0

    GROUP BY
        store_id,
        item_id,
        grupo_gap

    HAVING
        COUNT(*) >= 3
),


-- DEMANDA HISTÓRICA:
-- 28 DÍAS CALENDARIO ANTERIORES AL GAP

baseline AS (

    SELECT
        g.store_id,
        g.item_id,
        g.grupo_gap,
        g.fecha_inicio_gap,
        g.fecha_fin_gap,
        g.dias_gap,

        COUNT(s.transaction_date)
            AS dias_base,

        SUM(
            CASE
                WHEN s.unidades_vendidas > 0
                    THEN 1

                ELSE 0
            END
        ) AS dias_con_venta_base,

        AVG(s.unidades_vendidas)
            AS unidades_promedio_dia,

        AVG(s.gmv_dia)
            AS gmv_promedio_dia

    FROM gaps AS g

    LEFT JOIN serie_diaria AS s
        ON g.store_id = s.store_id
       AND g.item_id = s.item_id
       AND s.transaction_date
           BETWEEN
               g.fecha_inicio_gap - INTERVAL '28 days'
               AND
               g.fecha_inicio_gap - INTERVAL '1 day'

    GROUP BY
        g.store_id,
        g.item_id,
        g.grupo_gap,
        g.fecha_inicio_gap,
        g.fecha_fin_gap,
        g.dias_gap
),


-- ENRIQUECER CON TIENDA Y PRODUCTO

resultado AS (

    SELECT
        b.store_id,
        s.store_name,
        s.country,
        s.format,

        b.item_id,
        p.item_name,
        p.category,

        b.fecha_inicio_gap,
        b.fecha_fin_gap,
        b.dias_gap,

        b.dias_base,
        b.dias_con_venta_base,

        b.unidades_promedio_dia,
        b.gmv_promedio_dia,

        b.gmv_promedio_dia *
            b.dias_gap
            AS gmv_perdido_estimado

    FROM baseline AS b

    INNER JOIN stores AS s
        ON b.store_id = s.store_id

    INNER JOIN products AS p
        ON b.item_id = p.item_id

    WHERE
        b.dias_con_venta_base > 0
)


-- RESULTADO FINAL

SELECT
    store_id,
    store_name,
    country,
    format,

    item_id,
    item_name,
    category,

    fecha_inicio_gap,
    fecha_fin_gap,
    dias_gap,

    dias_base,
    dias_con_venta_base,

    ROUND(
        unidades_promedio_dia,
        2
    ) AS unidades_promedio_dia_antes_gap,

    ROUND(
        gmv_promedio_dia,
        2
    ) AS gmv_promedio_dia_antes_gap,

    ROUND(
        gmv_perdido_estimado,
        2
    ) AS gmv_perdido_estimado

FROM resultado

ORDER BY
    gmv_perdido_estimado DESC,
    dias_gap DESC;



-- ============================================================
-- QUERY 6 - IMPACTO DE PROMOCIONES EN TICKET Y VOLUMEN
-- ============================================================
-- Comparar por categoría el comportamiento de las transacciones
-- con y sin ítems promocionales.
--
-- Métricas:
--   - Ticket promedio
--   - Unidades promedio por transacción
--   - Número de transacciones
--   - Uplift de ticket
--   - Uplift de unidades
--
-- Solo se consideran transacciones COMPLETED.
--
-- Una transacción se clasifica como PROMO para una categoría
-- si contiene al menos un item de esa categoría con
-- was_on_promo = TRUE.
--
-- Se excluyen líneas con unit_price = 0 y
-- was_on_promo = FALSE por el hallazgo del Bloque 0.
--
-- Nota:
-- El ticket y las unidades corresponden al basket completo.
-- Una transacción puede contribuir al análisis de más de una
-- categoría si contiene productos de categorías diferentes.
-- Por esta razón, los resultados entre categorías no son
-- aditivos.
--
-- Este análisis muestra asociación y no implica causalidad.
-- ============================================================

WITH items_validos AS (

    SELECT
        ti.transaction_id,
        ti.item_id,
        ti.quantity,
        ti.unit_price,
        ti.was_on_promo,
        p.category

    FROM transaction_items AS ti

    INNER JOIN products AS p
        ON ti.item_id = p.item_id

    INNER JOIN transactions AS t
        ON ti.transaction_id = t.transaction_id

    WHERE
        t.status = 'COMPLETED'

        AND NOT (
            ti.unit_price = 0
            AND ti.was_on_promo = FALSE
        )
),


-- TAMAÑO TOTAL DEL BASKET POR TRANSACCIÓN

basket_transaccion AS (

    SELECT
        t.transaction_id,

        t.total_amount
            AS ticket,

        SUM(i.quantity)
            AS unidades_basket

    FROM transactions AS t

    INNER JOIN items_validos AS i
        ON t.transaction_id = i.transaction_id

    WHERE
        t.status = 'COMPLETED'

    GROUP BY
        t.transaction_id,
        t.total_amount
),


-- EXPOSICIÓN PROMOCIONAL POR TRANSACCIÓN Y CATEGORÍA

transaccion_categoria AS (

    SELECT
        transaction_id,
        category,

        MAX(
            CASE
                WHEN was_on_promo = TRUE
                    THEN 1

                ELSE 0
            END
        ) AS tiene_promo

    FROM items_validos

    GROUP BY
        transaction_id,
        category
),


-- BASE ANALÍTICA

base_analisis AS (

    SELECT
        tc.category,
        tc.tiene_promo,

        b.transaction_id,
        b.ticket,
        b.unidades_basket

    FROM transaccion_categoria AS tc

    INNER JOIN basket_transaccion AS b
        ON tc.transaction_id = b.transaction_id
),


-- MÉTRICAS PROMO VS. NO PROMO

metricas AS (

    SELECT
        category,
        tiene_promo,

        COUNT(DISTINCT transaction_id)
            AS transacciones,

        AVG(ticket)
            AS ticket_promedio,

        AVG(unidades_basket)
            AS unidades_promedio

    FROM base_analisis

    GROUP BY
        category,
        tiene_promo
),


-- PIVOT PROMO VS. NO PROMO

comparacion AS (

    SELECT
        category,

        MAX(
            CASE
                WHEN tiene_promo = 0
                    THEN transacciones
            END
        ) AS transacciones_sin_promo,

        MAX(
            CASE
                WHEN tiene_promo = 1
                    THEN transacciones
            END
        ) AS transacciones_con_promo,

        MAX(
            CASE
                WHEN tiene_promo = 0
                    THEN ticket_promedio
            END
        ) AS ticket_sin_promo,

        MAX(
            CASE
                WHEN tiene_promo = 1
                    THEN ticket_promedio
            END
        ) AS ticket_con_promo,

        MAX(
            CASE
                WHEN tiene_promo = 0
                    THEN unidades_promedio
            END
        ) AS unidades_sin_promo,

        MAX(
            CASE
                WHEN tiene_promo = 1
                    THEN unidades_promedio
            END
        ) AS unidades_con_promo

    FROM metricas

    GROUP BY
        category
),


-- CÁLCULO DE UPLIFT

resultado AS (

    SELECT
        *,

        100.0 *
        (
            ticket_con_promo -
            ticket_sin_promo
        )
        /
        NULLIF(
            ticket_sin_promo,
            0
        ) AS ticket_uplift_pct,

        100.0 *
        (
            unidades_con_promo -
            unidades_sin_promo
        )
        /
        NULLIF(
            unidades_sin_promo,
            0
        ) AS unidades_uplift_pct

    FROM comparacion
)


-- RESULTADO FINAL

SELECT
    category,

    transacciones_sin_promo,
    transacciones_con_promo,

    ROUND(
        ticket_sin_promo,
        2
    ) AS ticket_promedio_sin_promo,

    ROUND(
        ticket_con_promo,
        2
    ) AS ticket_promedio_con_promo,

    ROUND(
        ticket_uplift_pct,
        2
    ) AS ticket_uplift_pct,

    ROUND(
        unidades_sin_promo,
        2
    ) AS unidades_promedio_sin_promo,

    ROUND(
        unidades_con_promo,
        2
    ) AS unidades_promedio_con_promo,

    ROUND(
        unidades_uplift_pct,
        2
    ) AS unidades_uplift_pct,

    CASE
        WHEN unidades_uplift_pct > 0
             AND ticket_uplift_pct > 0
            THEN 'POSIBLE_BASKET_UPLIFT'

        WHEN unidades_uplift_pct > 0
             AND ticket_uplift_pct <= 0
            THEN 'MAS_UNIDADES_CON_MENOR_TICKET'

        WHEN unidades_uplift_pct <= 0
             AND ticket_uplift_pct < 0
            THEN 'POSIBLE_EFECTO_DESCUENTO'

        ELSE 'SIN_EVIDENCIA_CLARA_DE_UPLIFT'
    END AS interpretacion

FROM resultado

ORDER BY
    unidades_uplift_pct DESC;