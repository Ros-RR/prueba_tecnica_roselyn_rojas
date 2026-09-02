# ============================================================
# BLOQUE 3 - ANALISIS EXPLORATORIO
# ============================================================

library(dplyr)
library(lubridate)
library(ggplot2)
library(scales)
library(here)

source(
  here::here(
    "R",
    "01_ingesta.R"
  )
)


# ============================================================
# 3.1 ESTACIONALIDAD POR FORMATO
# ============================================================

# PREPARAR BASE DE VENTAS

ventas_formato <- transactions %>%
  inner_join(
    stores %>%
      select(
        store_id,
        format,
        country
      ),
    by = "store_id"
  ) %>%
  mutate(
    gmv_neto = case_when(
      status == "COMPLETED" ~ total_amount,
      status == "RETURNED"  ~ -total_amount,
      TRUE                  ~ 0
    ),
    
    semana = floor_date(
      transaction_date,
      unit = "week",
      week_start = 1
    )
  )


# RANGO DE FECHAS DEL DATASET


fecha_minima <- min(
  transactions$transaction_date,
  na.rm = TRUE
)

fecha_maxima <- max(
  transactions$transaction_date,
  na.rm = TRUE
)


# GMV SEMANAL POR FORMATO
# Solo semanas completas


gmv_semanal_formato <- ventas_formato %>%
  mutate(
    fin_semana = semana + days(6)
  ) %>%
  filter(
    semana >= fecha_minima,
    fin_semana <= fecha_maxima
  ) %>%
  group_by(
    semana,
    format
  ) %>%
  summarise(
    gmv = sum(
      gmv_neto,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


print(
  gmv_semanal_formato,
  n = 20
)


# GRAFICO DE GMV SEMANAL

grafico_estacionalidad <- ggplot(
  gmv_semanal_formato,
  aes(
    x = semana,
    y = gmv,
    group = format,
    color = format
  )
) +
  geom_line(
    linewidth = 0.8
  ) +
  labs(
    title = "Evolución semanal del GMV por formato",
    x = NULL,
    y = "GMV neto",
    color = "Formato"
  ) +
  scale_y_continuous(
    labels = label_number(
      big.mark = ","
    )
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom"
  )


grafico_estacionalidad


# GUARDAR GRAFICO

ggsave(
  filename = here::here(
    "bloque3_visualizaciones",
    "01_gmv_semanal_formato.png"
  ),
  plot = grafico_estacionalidad,
  width = 11,
  height = 6,
  dpi = 300
)


# SENSIBILIDAD DEL FORMATO A FLUCTUACIONES SEMANALES

# Se utiliza el coeficiente de variación como medida
# de volatilidad relativa del GMV semanal.


sensibilidad_formato <- gmv_semanal_formato %>%
  group_by(
    format
  ) %>%
  summarise(
    semanas = n(),
    
    gmv_promedio = mean(
      gmv,
      na.rm = TRUE
    ),
    
    desviacion_gmv = sd(
      gmv,
      na.rm = TRUE
    ),
    
    coef_variacion =
      desviacion_gmv /
      gmv_promedio,
    
    .groups = "drop"
  ) %>%
  arrange(
    desc(coef_variacion)
  )


print(
  sensibilidad_formato
)


# VARIACION SEMANAL POR FORMATO

variacion_semanal <- gmv_semanal_formato %>%
  arrange(
    format,
    semana
  ) %>%
  group_by(
    format
  ) %>%
  mutate(
    gmv_semana_anterior = lag(gmv),
    
    variacion_absoluta =
      gmv -
      gmv_semana_anterior,
    
    variacion_pct = if_else(
      !is.na(gmv_semana_anterior) &
        gmv_semana_anterior != 0,
      
      100 *
        (
          gmv -
            gmv_semana_anterior
        ) /
        gmv_semana_anterior,
      
      NA_real_
    )
  ) %>%
  ungroup()

# TOP 3 PICOS

top_3_picos <- variacion_semanal %>%
  filter(
    !is.na(variacion_pct)
  ) %>%
  arrange(
    desc(variacion_pct)
  ) %>%
  slice_head(
    n = 3
  )


print(
  top_3_picos
)

# TOP 3 CAIDAS

top_3_caidas <- variacion_semanal %>%
  filter(
    !is.na(variacion_pct)
  ) %>%
  arrange(
    variacion_pct
  ) %>%
  slice_head(
    n = 3
  )


print(
  top_3_caidas
)


# SEMANAS EXTREMAS

extremos <- bind_rows(
  
  top_3_picos %>%
    mutate(
      tipo_movimiento = "PICO"
    ),
  
  top_3_caidas %>%
    mutate(
      tipo_movimiento = "CAIDA"
    )
  
) %>%
  select(
    semana,
    format,
    tipo_movimiento,
    variacion_pct
  )


print(
  extremos
)


# CONTRIBUCION AL CAMBIO - PAIS

gmv_semanal_pais <- ventas_formato %>%
  mutate(
    fin_semana = semana + days(6)
  ) %>%
  filter(
    semana >= fecha_minima,
    fin_semana <= fecha_maxima
  ) %>%
  group_by(
    semana,
    format,
    country
  ) %>%
  summarise(
    gmv = sum(
      gmv_neto,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


contribucion_extremos_pais <- extremos %>%
  inner_join(
    gmv_semanal_pais,
    by = c(
      "semana",
      "format"
    )
  ) %>%
  rename(
    gmv_semana_actual = gmv
  ) %>%
  mutate(
    semana_anterior =
      semana -
      days(7)
  ) %>%
  left_join(
    gmv_semanal_pais %>%
      select(
        semana,
        format,
        country,
        gmv
      ),
    by = c(
      "semana_anterior" = "semana",
      "format",
      "country"
    )
  ) %>%
  rename(
    gmv_semana_anterior = gmv
  ) %>%
  mutate(
    gmv_semana_anterior =
      coalesce(
        gmv_semana_anterior,
        0
      ),
    
    cambio_gmv =
      gmv_semana_actual -
      gmv_semana_anterior
  ) %>%
  group_by(
    semana,
    format
  ) %>%
  mutate(
    cambio_total =
      sum(
        cambio_gmv,
        na.rm = TRUE
      ),
    
    contribucion_cambio_pct =
      if_else(
        cambio_total != 0,
        
        100 *
          cambio_gmv /
          cambio_total,
        
        NA_real_
      )
  ) %>%
  ungroup() %>%
  arrange(
    semana,
    desc(
      abs(cambio_gmv)
    )
  )


print(
  contribucion_extremos_pais,
  n = Inf
)

# CONTRIBUCION AL CAMBIO - TIENDA

gmv_semanal_tienda <- ventas_formato %>%
  mutate(
    fin_semana = semana + days(6)
  ) %>%
  filter(
    semana >= fecha_minima,
    fin_semana <= fecha_maxima
  ) %>%
  group_by(
    semana,
    format,
    store_id
  ) %>%
  summarise(
    gmv = sum(
      gmv_neto,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


contribucion_extremos_tienda <- extremos %>%
  inner_join(
    gmv_semanal_tienda,
    by = c(
      "semana",
      "format"
    )
  ) %>%
  rename(
    gmv_semana_actual = gmv
  ) %>%
  mutate(
    semana_anterior =
      semana -
      days(7)
  ) %>%
  left_join(
    gmv_semanal_tienda %>%
      select(
        semana,
        format,
        store_id,
        gmv
      ),
    by = c(
      "semana_anterior" = "semana",
      "format",
      "store_id"
    )
  ) %>%
  rename(
    gmv_semana_anterior = gmv
  ) %>%
  mutate(
    gmv_semana_anterior =
      coalesce(
        gmv_semana_anterior,
        0
      ),
    
    cambio_gmv =
      gmv_semana_actual -
      gmv_semana_anterior
  ) %>%
  group_by(
    semana,
    format
  ) %>%
  mutate(
    cambio_total =
      sum(
        cambio_gmv,
        na.rm = TRUE
      ),
    
    contribucion_cambio_pct =
      if_else(
        cambio_total != 0,
        
        100 *
          cambio_gmv /
          cambio_total,
        
        NA_real_
      )
  ) %>%
  ungroup() %>%
  arrange(
    semana,
    desc(
      abs(cambio_gmv)
    )
  )


print(
  contribucion_extremos_tienda,
  n = Inf
)

# TOP 5 TIENDAS QUE MAS CONTRIBUYEN EN CADA SEMANA EXTREMA

top_tiendas_extremos <- contribucion_extremos_tienda %>%
  group_by(
    semana,
    format,
    tipo_movimiento
  ) %>%
  slice_max(
    order_by = abs(cambio_gmv),
    n = 5,
    with_ties = FALSE
  ) %>%
  ungroup() %>%
  arrange(
    semana,
    desc(
      abs(cambio_gmv)
    )
  )


print(
  top_tiendas_extremos,
  n = Inf
)



# ============================================================
# 3.2 PARETO DE CATEGORIAS POR FORMATO
# ============================================================

ventas_categoria <- transaction_items %>%
  inner_join(
    transactions %>%
      select(
        transaction_id,
        store_id,
        status
      ),
    by = "transaction_id"
  ) %>%
  inner_join(
    products %>%
      select(
        item_id,
        category
      ),
    by = "item_id"
  ) %>%
  inner_join(
    stores %>%
      select(
        store_id,
        format
      ),
    by = "store_id"
  ) %>%
  filter(
    !(unit_price == 0 & was_on_promo == FALSE)
  ) %>%
  mutate(
    gmv_linea = case_when(
      status == "COMPLETED" ~ quantity * unit_price,
      status == "RETURNED"  ~ -(quantity * unit_price),
      TRUE                  ~ 0
    )
  )


# GMV POR FORMATO Y CATEGORIA

pareto_categoria <- ventas_categoria %>%
  group_by(
    format,
    category
  ) %>%
  summarise(
    gmv = sum(
      gmv_linea,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  group_by(
    format
  ) %>%
  arrange(
    desc(gmv),
    .by_group = TRUE
  ) %>%
  mutate(
    participacion_pct =
      100 * gmv / sum(gmv),
    
    participacion_acumulada_pct =
      cumsum(participacion_pct),
    
    orden_categoria =
      row_number()
  ) %>%
  ungroup()


print(
  pareto_categoria,
  n = Inf
)

# CATEGORIAS QUE CONCENTRAN APROXIMADAMENTE EL 80% DEL GMV

categorias_80 <- pareto_categoria %>%
  group_by(
    format
  ) %>%
  mutate(
    acumulado_anterior =
      lag(
        participacion_acumulada_pct,
        default = 0
      )
  ) %>%
  filter(
    acumulado_anterior < 80
  ) %>%
  ungroup()


print(
  categorias_80,
  n = Inf
)

# COMPARAR HIPERMERCADO VS DESCUENTO

comparacion_formatos <- categorias_80 %>%
  filter(
    format %in% c(
      "HIPERMERCADO",
      "DESCUENTO"
    )
  ) %>%
  select(
    format,
    orden_categoria,
    category,
    gmv,
    participacion_pct,
    participacion_acumulada_pct
  )


print(
  comparacion_formatos,
  n = Inf
)

# GRAFICO PARETO

grafico_pareto <- ggplot(
  pareto_categoria,
  aes(
    x = reorder(category, -gmv),
    y = participacion_acumulada_pct,
    group = 1
  )
) +
  geom_line() +
  geom_point() +
  geom_hline(
    yintercept = 80,
    linetype = "dashed"
  ) +
  facet_wrap(
    ~ format,
    scales = "free_x"
  ) +
  labs(
    title = "Pareto de categorías por formato",
    x = NULL,
    y = "Participación acumulada del GMV (%)"
  ) +
  scale_y_continuous(
    limits = c(0, 100)
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )


grafico_pareto

# GUARDAR GRAFICO

ggsave(
  filename = here::here(
    "bloque3_visualizaciones",
    "02_pareto_categorias_formato.png"
  ),
  plot = grafico_pareto,
  width = 12,
  height = 7,
  dpi = 300
)


# ============================================================
# 3.3 COHORTES DE LEALTAD
# ============================================================

# TRANSACCIONES DE CLIENTES IDENTIFICADOS

ventas_lealtad <- transactions %>%
  filter(
    loyalty_card == TRUE,
    !is.na(customer_id),
    customer_id != "",
    status == "COMPLETED"
  ) %>%
  mutate(
    mes_transaccion = floor_date(
      transaction_date,
      unit = "month"
    )
  )


# PRIMERA COMPRA Y COHORTE


cohortes_cliente <- ventas_lealtad %>%
  group_by(
    customer_id
  ) %>%
  summarise(
    mes_cohorte = min(mes_transaccion),
    .groups = "drop"
  )


# ACTIVIDAD DEL CLIENTE POR MES


actividad_cliente_mes <- ventas_lealtad %>%
  inner_join(
    cohortes_cliente,
    by = "customer_id"
  ) %>%
  mutate(
    mes_desde_cohorte =
      (
        year(mes_transaccion) -
          year(mes_cohorte)
      ) * 12 +
      (
        month(mes_transaccion) -
          month(mes_cohorte)
      )
  ) %>%
  filter(
    mes_desde_cohorte >= 0,
    mes_desde_cohorte <= 6
  ) %>%
  group_by(
    customer_id,
    mes_cohorte,
    mes_desde_cohorte
  ) %>%
  summarise(
    transacciones = n_distinct(transaction_id),
    
    gmv = sum(
      total_amount,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  )


# TAMAÑO DE CADA COHORTE


tamano_cohorte <- cohortes_cliente %>%
  count(
    mes_cohorte,
    name = "tamano_cohorte"
  )

# CLIENTES ACTIVOS POR COHORTE Y MES

actividad_cohorte <- actividad_cliente_mes %>%
  group_by(
    mes_cohorte,
    mes_desde_cohorte
  ) %>%
  summarise(
    clientes_activos =
      n_distinct(customer_id),
    
    transacciones =
      sum(transacciones),
    
    gmv =
      sum(gmv),
    
    .groups = "drop"
  )

# CREAR TODAS LAS COMBINACIONES COHORTE / MES 0-6

grilla_cohortes <- merge(
  tamano_cohorte,
  data.frame(
    mes_desde_cohorte = 0:6
  ),
  all = TRUE
) %>%
  as_tibble()


ultimo_mes_observable <- floor_date(
  fecha_maxima,
  unit = "month"
)

# RETENCION POR COHORTE

retencion_cohortes <- grilla_cohortes %>%
  left_join(
    actividad_cohorte,
    by = c(
      "mes_cohorte",
      "mes_desde_cohorte"
    )
  ) %>%
  mutate(
    mes_evaluado =
      mes_cohorte %m+%
      months(mes_desde_cohorte),
    
    es_observable =
      mes_evaluado <=
      ultimo_mes_observable,
    
    clientes_activos = case_when(
      es_observable &
        is.na(clientes_activos) ~ 0,
      
      !es_observable ~ NA_real_,
      
      TRUE ~ as.numeric(clientes_activos)
    ),
    
    retencion_pct =
      100 *
      clientes_activos /
      tamano_cohorte,
    
    ticket_promedio = case_when(
      es_observable &
        !is.na(transacciones) &
        transacciones > 0 ~
        gmv / transacciones,
      
      TRUE ~ NA_real_
    )
  )

# TABLA DE RETENCION POR COHORTE
# M1, M2, M3 Y M6

retencion_principal <- retencion_cohortes %>%
  filter(
    mes_desde_cohorte %in%
      c(1, 2, 3, 6)
  ) %>%
  select(
    mes_cohorte,
    mes_desde_cohorte,
    tamano_cohorte,
    clientes_activos,
    retencion_pct,
    ticket_promedio
  ) %>%
  arrange(
    mes_cohorte,
    mes_desde_cohorte
  )


print(
  retencion_principal,
  n = Inf
)

# CURVA GENERAL DE RETENCION
# Se pondera por tamaño de cohorte.

resumen_retencion <- retencion_cohortes %>%
  filter(
    es_observable
  ) %>%
  group_by(
    mes_desde_cohorte
  ) %>%
  summarise(
    clientes_base =
      sum(tamano_cohorte),
    
    clientes_activos =
      sum(
        clientes_activos,
        na.rm = TRUE
      ),
    
    retencion_pct =
      100 *
      clientes_activos /
      clientes_base,
    
    transacciones =
      sum(
        transacciones,
        na.rm = TRUE
      ),
    
    gmv =
      sum(
        gmv,
        na.rm = TRUE
      ),
    
    ticket_promedio =
      gmv /
      transacciones,
    
    .groups = "drop"
  )


print(
  resumen_retencion
)

# MAYOR CAIDA DE RETENCION

caidas_retencion <- resumen_retencion %>%
  arrange(
    mes_desde_cohorte
  ) %>%
  mutate(
    retencion_anterior =
      lag(retencion_pct),
    
    cambio_retencion_pp =
      retencion_pct -
      retencion_anterior
  )


mayor_caida_retencion <- caidas_retencion %>%
  filter(
    !is.na(cambio_retencion_pp)
  ) %>%
  arrange(
    cambio_retencion_pp
  ) %>%
  slice_head(
    n = 1
  )


print(
  caidas_retencion
)

print(
  mayor_caida_retencion
)

# COHORTES ANTIGUAS VS RECIENTES
# Para cada horizonte de retencion se dividen las cohortes
# observables en dos grupos utilizando la mediana temporal.


comparacion_cohortes <- retencion_cohortes %>%
  filter(
    es_observable,
    mes_desde_cohorte %in%
      c(1, 3, 6)
  ) %>%
  group_by(
    mes_desde_cohorte
  ) %>%
  mutate(
    mediana_cohorte =
      median(mes_cohorte),
    
    grupo_cohorte = if_else(
      mes_cohorte <= mediana_cohorte,
      "ANTIGUAS",
      "RECIENTES"
    )
  ) %>%
  group_by(
    mes_desde_cohorte,
    grupo_cohorte
  ) %>%
  summarise(
    cohortes =
      n_distinct(mes_cohorte),
    
    clientes_base =
      sum(tamano_cohorte),
    
    clientes_activos =
      sum(
        clientes_activos,
        na.rm = TRUE
      ),
    
    retencion_pct =
      100 *
      clientes_activos /
      clientes_base,
    
    .groups = "drop"
  ) %>%
  arrange(
    mes_desde_cohorte,
    grupo_cohorte
  )


print(
  comparacion_cohortes
)


# GRAFICO - RETENCION POR COHORTE

grafico_retencion_cohortes <- retencion_cohortes %>%
  filter(
    es_observable
  ) %>%
  ggplot(
    aes(
      x = factor(
        mes_desde_cohorte
      ),
      y = mes_cohorte,
      fill = retencion_pct
    )
  ) +
  geom_tile() +
  labs(
    title = "Retención de clientes por cohorte",
    x = "Mes desde primera compra",
    y = "Cohorte",
    fill = "Retención %"
  ) +
  theme_minimal()


grafico_retencion_cohortes

## GUARDAR GRAFICO

ggsave(
  filename = here::here(
    "bloque3_visualizaciones",
    "03_retencion_cohortes.png"
  ),
  plot = grafico_retencion_cohortes,
  width = 10,
  height = 7,
  dpi = 300
)

# GRAFICO - TICKET DE CLIENTES RETENIDOS

grafico_ticket_retenidos <- resumen_retencion %>%
  filter(
    mes_desde_cohorte > 0
  ) %>%
  ggplot(
    aes(
      x = mes_desde_cohorte,
      y = ticket_promedio
    )
  ) +
  geom_line(
    linewidth = 0.8
  ) +
  geom_point() +
  labs(
    title = "Evolución del ticket de clientes retenidos",
    x = "Mes desde primera compra",
    y = "Ticket promedio"
  ) +
  theme_minimal()


grafico_ticket_retenidos

## GUARDAR GRAFICO

ggsave(
  filename = here::here(
    "bloque3_visualizaciones",
    "04_ticket_clientes_retenidos.png"
  ),
  plot = grafico_ticket_retenidos,
  width = 9,
  height = 5,
  dpi = 300
)

# ============================================================
# 3.4 POSIBLES QUIEBRES DE STOCK E IMPACTO
# ============================================================

# VENTAS DIARIAS POR TIENDA E ITEM

ventas_diarias_item <- transaction_items %>%
  inner_join(
    transactions %>%
      select(
        transaction_id,
        transaction_date,
        store_id,
        status
      ),
    by = "transaction_id"
  ) %>%
  filter(
    status == "COMPLETED"
  ) %>%
  mutate(
    gmv_linea = case_when(
      unit_price == 0 &
        was_on_promo == FALSE ~ 0,
      
      TRUE ~ quantity * unit_price
    )
  ) %>%
  group_by(
    store_id,
    item_id,
    transaction_date
  ) %>%
  summarise(
    unidades_vendidas = sum(
      quantity,
      na.rm = TRUE
    ),
    
    gmv_dia = sum(
      gmv_linea,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  )

# PRIMERA Y ULTIMA VENTA POR TIENDA / ITEM

rango_item_tienda <- ventas_diarias_item %>%
  filter(
    unidades_vendidas > 0
  ) %>%
  group_by(
    store_id,
    item_id
  ) %>%
  summarise(
    primera_venta = min(transaction_date),
    ultima_venta = max(transaction_date),
    .groups = "drop"
  )


# CALENDARIO DIARIO


calendario_item_tienda <- rango_item_tienda %>%
  rowwise() %>%
  reframe(
    store_id = store_id,
    item_id = item_id,
    
    transaction_date = seq(
      primera_venta,
      ultima_venta,
      by = "day"
    )
  )


# COMPLETAR DIAS SIN VENTA


serie_diaria_item <- calendario_item_tienda %>%
  left_join(
    ventas_diarias_item,
    by = c(
      "store_id",
      "item_id",
      "transaction_date"
    )
  ) %>%
  mutate(
    unidades_vendidas =
      coalesce(
        unidades_vendidas,
        0
      ),
    
    gmv_dia =
      coalesce(
        gmv_dia,
        0
      )
  )


# BASELINE DE LOS 28 DIAS ANTERIORES


serie_diaria_item <- serie_diaria_item %>%
  arrange(
    store_id,
    item_id,
    transaction_date
  ) %>%
  group_by(
    store_id,
    item_id
  ) %>%
  mutate(
    fila = row_number(),
    
    acumulado_gmv =
      cumsum(gmv_dia),
    
    acumulado_unidades =
      cumsum(unidades_vendidas),
    
    acumulado_dias_venta =
      cumsum(
        unidades_vendidas > 0
      ),
    
    gmv_28_dias_previos =
      lag(
        acumulado_gmv,
        1,
        default = 0
      ) -
      lag(
        acumulado_gmv,
        29,
        default = 0
      ),
    
    unidades_28_dias_previos =
      lag(
        acumulado_unidades,
        1,
        default = 0
      ) -
      lag(
        acumulado_unidades,
        29,
        default = 0
      ),
    
    dias_con_venta_28 =
      lag(
        acumulado_dias_venta,
        1,
        default = 0
      ) -
      lag(
        acumulado_dias_venta,
        29,
        default = 0
      ),
    
    dias_base =
      pmin(
        fila - 1,
        28
      ),
    
    gmv_promedio_dia_antes_gap =
      if_else(
        dias_base > 0,
        gmv_28_dias_previos /
          dias_base,
        NA_real_
      ),
    
    unidades_promedio_dia_antes_gap =
      if_else(
        dias_base > 0,
        unidades_28_dias_previos /
          dias_base,
        NA_real_
      )
  ) %>%
  ungroup()


# IDENTIFICAR GAPS CONSECUTIVOS


serie_gaps <- serie_diaria_item %>%
  arrange(
    store_id,
    item_id,
    transaction_date
  ) %>%
  group_by(
    store_id,
    item_id
  ) %>%
  mutate(
    grupo_gap =
      cumsum(
        unidades_vendidas > 0
      )
  ) %>%
  ungroup()


gaps_stock <- serie_gaps %>%
  filter(
    unidades_vendidas == 0
  ) %>%
  group_by(
    store_id,
    item_id,
    grupo_gap
  ) %>%
  summarise(
    fecha_inicio_gap =
      min(transaction_date),
    
    fecha_fin_gap =
      max(transaction_date),
    
    dias_gap = n(),
    
    .groups = "drop"
  ) %>%
  filter(
    dias_gap >= 3
  )

# INCORPORAR BASELINE PREVIO AL GAP

baseline_gap <- serie_diaria_item %>%
  select(
    store_id,
    item_id,
    transaction_date,
    dias_base,
    dias_con_venta_28,
    unidades_promedio_dia_antes_gap,
    gmv_promedio_dia_antes_gap
  )


quiebres_stock <- gaps_stock %>%
  left_join(
    baseline_gap,
    by = c(
      "store_id",
      "item_id",
      "fecha_inicio_gap" =
        "transaction_date"
    )
  ) %>%
  filter(
    dias_con_venta_28 > 0
  ) %>%
  mutate(
    gmv_perdido_estimado =
      gmv_promedio_dia_antes_gap *
      dias_gap
  )


# ENRIQUECER CON PRODUCTO, PROVEEDOR Y TIENDA


quiebres_stock <- quiebres_stock %>%
  inner_join(
    products %>%
      select(
        item_id,
        item_name,
        category,
        vendor_id
      ),
    by = "item_id"
  ) %>%
  left_join(
    vendors %>%
      select(
        vendor_id,
        vendor_name
      ),
    by = "vendor_id"
  ) %>%
  inner_join(
    stores %>%
      select(
        store_id,
        country,
        format
      ),
    by = "store_id"
  ) %>%
  mutate(
    vendor_name =
      coalesce(
        vendor_name,
        "VENDOR_NO_ENCONTRADO"
      )
  )


# IMPACTO TOTAL
resumen_quiebres <- quiebres_stock %>%
  summarise(
    cantidad_gaps = n(),
    
    tiendas_afectadas =
      n_distinct(store_id),
    
    productos_afectados =
      n_distinct(item_id),
    
    gmv_perdido_estimado =
      sum(
        gmv_perdido_estimado,
        na.rm = TRUE
      )
  )


print(
  resumen_quiebres
)


# QUIEBRES POR CATEGORIA


quiebres_categoria <- quiebres_stock %>%
  group_by(
    category
  ) %>%
  summarise(
    cantidad_gaps = n(),
    
    tiendas_afectadas =
      n_distinct(store_id),
    
    productos_afectados =
      n_distinct(item_id),
    
    duracion_promedio =
      mean(
        dias_gap,
        na.rm = TRUE
      ),
    
    gmv_perdido_estimado =
      sum(
        gmv_perdido_estimado,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  ) %>%
  mutate(
    participacion_gmv_perdido_pct =
      100 *
      gmv_perdido_estimado /
      sum(gmv_perdido_estimado)
  ) %>%
  arrange(
    desc(gmv_perdido_estimado)
  )


print(
  quiebres_categoria,
  n = Inf
)

# QUIEBRES POR PROVEEDOR

quiebres_vendor <- quiebres_stock %>%
  group_by(
    vendor_id,
    vendor_name
  ) %>%
  summarise(
    cantidad_gaps = n(),
    
    tiendas_afectadas =
      n_distinct(store_id),
    
    productos_afectados =
      n_distinct(item_id),
    
    gmv_perdido_estimado =
      sum(
        gmv_perdido_estimado,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  ) %>%
  mutate(
    participacion_gmv_perdido_pct =
      100 *
      gmv_perdido_estimado /
      sum(gmv_perdido_estimado)
  ) %>%
  arrange(
    desc(gmv_perdido_estimado)
  )


print(
  quiebres_vendor,
  n = 15
)


# ITEMS CON QUIEBRES EN MULTIPLES TIENDAS
# Un mismo SKU con gaps en varias tiendas puede ser una
# señal más consistente con un problema de abastecimiento.
# No implica causalidad sin datos de inventario.


quiebres_item <- quiebres_stock %>%
  group_by(
    item_id,
    item_name,
    category,
    vendor_id,
    vendor_name
  ) %>%
  summarise(
    cantidad_gaps = n(),
    
    tiendas_afectadas =
      n_distinct(store_id),
    
    paises_afectados =
      n_distinct(country),
    
    gmv_perdido_estimado =
      sum(
        gmv_perdido_estimado,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  ) %>%
  arrange(
    desc(tiendas_afectadas),
    desc(gmv_perdido_estimado)
  )


items_quiebres_sistematicos <- quiebres_item %>%
  filter(
    tiendas_afectadas >= 3
  )


print(
  items_quiebres_sistematicos,
  n = 20
)

# GRAFICO - GMV PERDIDO POR CATEGORIA

grafico_quiebres_categoria <- quiebres_categoria %>%
  ggplot(
    aes(
      x = reorder(
        category,
        gmv_perdido_estimado
      ),
      y = gmv_perdido_estimado
    )
  ) +
  geom_col() +
  coord_flip() +
  labs(
    title = "GMV estimado perdido por posibles quiebres",
    x = NULL,
    y = "GMV perdido estimado"
  ) +
  scale_y_continuous(
    labels = label_number(
      big.mark = ","
    )
  ) +
  theme_minimal()


grafico_quiebres_categoria

## GUARDAR GRAFICO

ggsave(
  filename = here::here(
    "bloque3_visualizaciones",
    "05_quiebres_stock_categoria.png"
  ),
  plot = grafico_quiebres_categoria,
  width = 9,
  height = 6,
  dpi = 300
)

# VALIDACION DE CONCENTRACION DE QUIEBRES

validacion_quiebres_categoria <- quiebres_categoria %>%
  mutate(
    gaps_por_producto =
      cantidad_gaps /
      productos_afectados,
    
    gmv_estimado_por_gap =
      gmv_perdido_estimado /
      cantidad_gaps
  ) %>%
  select(
    category,
    cantidad_gaps,
    productos_afectados,
    gaps_por_producto,
    gmv_perdido_estimado,
    participacion_gmv_perdido_pct,
    gmv_estimado_por_gap
  )

print(
  validacion_quiebres_categoria,
  n = Inf
)


# ============================================================
# 3.5 HALLAZGO LIBRE
# LEALTAD VS. NO LEALTAD
# ============================================================

hallazgo_lealtad <- transactions %>%
  mutate(
    grupo_lealtad = if_else(
      loyalty_card == TRUE,
      "CON_LEALTAD",
      "SIN_LEALTAD"
    ),
    gmv_neto = case_when(
      status == "COMPLETED" ~ total_amount,
      status == "RETURNED"  ~ -total_amount,
      TRUE                  ~ 0
    )
  ) %>%
  group_by(
    grupo_lealtad
  ) %>%
  summarise(
    transacciones = n_distinct(transaction_id),
    
    gmv_neto = sum(
      gmv_neto,
      na.rm = TRUE
    ),
    
    ticket_promedio = mean(
      total_amount[
        status == "COMPLETED"
      ],
      na.rm = TRUE
    ),
    
    .groups = "drop"
  ) %>%
  mutate(
    participacion_gmv_pct =
      100 * gmv_neto / sum(gmv_neto)
  )


print(
  hallazgo_lealtad
)

# LEALTAD POR FORMATO

hallazgo_lealtad_formato <- transactions %>%
  inner_join(
    stores %>%
      select(
        store_id,
        format
      ),
    by = "store_id"
  ) %>%
  filter(
    status == "COMPLETED"
  ) %>%
  mutate(
    grupo_lealtad = if_else(
      loyalty_card == TRUE,
      "CON_LEALTAD",
      "SIN_LEALTAD"
    )
  ) %>%
  group_by(
    format,
    grupo_lealtad
  ) %>%
  summarise(
    transacciones =
      n_distinct(transaction_id),
    
    ticket_promedio =
      mean(
        total_amount,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  )


print(
  hallazgo_lealtad_formato,
  n = Inf
)

# GRAFICO

grafico_hallazgo_lealtad <- ggplot(
  hallazgo_lealtad_formato,
  aes(
    x = format,
    y = ticket_promedio,
    fill = grupo_lealtad
  )
) +
  geom_col(
    position = "dodge"
  ) +
  labs(
    title = "Ticket promedio según uso de tarjeta de lealtad",
    x = NULL,
    y = "Ticket promedio",
    fill = "Cliente"
  ) +
  theme_minimal()


grafico_hallazgo_lealtad

## GUARDAR GRAFICO

ggsave(
  filename = here::here(
    "bloque3_visualizaciones",
    "06_ticket_lealtad_formato.png"
  ),
  plot = grafico_hallazgo_lealtad,
  width = 9,
  height = 5,
  dpi = 300
)
