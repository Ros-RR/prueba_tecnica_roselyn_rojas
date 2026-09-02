# AUDITORÍA DE CALIDAD DE DATOS
# ============================================================

source(here::here("R", "01_ingesta.R"))

# Tolerancia utilizada para comparaciones monetarias
TOLERANCIA_MONTO <- 0.01

# ============================================================
# 1. COMPLETITUD
# ============================================================

aud_completitud <- transactions %>%
  summarise(
    total_transacciones = n(),
    
    customer_id_nulo =
      sum(is.na(customer_id)),
    
    pct_customer_id_nulo =
      round(
        100 * customer_id_nulo / total_transacciones,
        2
      ),
    
    nulo_sin_lealtad =
      sum(
        is.na(customer_id) &
          loyalty_card == FALSE,
        na.rm = TRUE
      ),
    
    nulo_con_lealtad =
      sum(
        is.na(customer_id) &
          loyalty_card == TRUE,
        na.rm = TRUE
      ),
    
    customer_presente_sin_lealtad =
      sum(
        !is.na(customer_id) &
          loyalty_card == FALSE,
        na.rm = TRUE
      ),
    
    customer_presente_con_lealtad =
      sum(
        !is.na(customer_id) &
          loyalty_card == TRUE,
        na.rm = TRUE
      )
  )

print(aud_completitud, width = Inf)

# ============================================================
# 2. CONSISTENCIA DE MONTOS
# ============================================================

total_items_transaccion <- transaction_items %>%
  mutate(
    monto_linea = quantity * unit_price
  ) %>%
  group_by(transaction_id) %>%
  summarise(
    monto_calculado_items = sum(monto_linea),
    cantidad_lineas = n(),
    .groups = "drop"
  )

consistencia_montos <- transactions %>%
  left_join(
    total_items_transaccion,
    by = "transaction_id"
  ) %>%
  mutate(
    diferencia_monto =
      total_amount - monto_calculado_items,
    
    diferencia_absoluta =
      abs(diferencia_monto),
    
    coincide =
      !is.na(monto_calculado_items) &
      diferencia_absoluta <= TOLERANCIA_MONTO
  )

aud_consistencia <- consistencia_montos %>%
  summarise(
    total_transacciones = n(),
    
    coinciden =
      sum(coincide, na.rm = TRUE),
    
    no_coinciden =
      sum(!coincide, na.rm = TRUE),
    
    sin_detalle =
      sum(is.na(monto_calculado_items)),
    
    pct_no_coinciden =
      round(
        100 * no_coinciden / total_transacciones,
        2
      ),
    
    diferencia_promedio =
      mean(diferencia_absoluta, na.rm = TRUE),
    
    diferencia_maxima =
      max(diferencia_absoluta, na.rm = TRUE)
  )

print(aud_consistencia, width = Inf)


## MAGNITUD DE DIFERFENCIAS

detalle_montos_inconsistentes <- consistencia_montos %>%
  filter(
    is.na(monto_calculado_items) |
      diferencia_absoluta > TOLERANCIA_MONTO
  ) %>%
  arrange(
    desc(diferencia_absoluta)
  )


aud_magnitud_diferencias <- detalle_montos_inconsistentes %>%
  filter(!is.na(monto_calculado_items)) %>%
  summarise(
    transacciones_inconsistentes = n(),
    
    diferencia_minima =
      min(diferencia_absoluta, na.rm = TRUE),
    
    diferencia_promedio =
      mean(diferencia_absoluta, na.rm = TRUE),
    
    mediana =
      median(diferencia_absoluta, na.rm = TRUE),
    
    percentil_75 =
      quantile(
        diferencia_absoluta,
        0.75,
        na.rm = TRUE
      ),
    
    percentil_90 =
      quantile(
        diferencia_absoluta,
        0.90,
        na.rm = TRUE
      ),
    
    percentil_95 =
      quantile(
        diferencia_absoluta,
        0.95,
        na.rm = TRUE
      ),
    
    percentil_99 =
      quantile(
        diferencia_absoluta,
        0.99,
        na.rm = TRUE
      ),
    
    diferencia_maxima =
      max(diferencia_absoluta, na.rm = TRUE)
  )

print(aud_magnitud_diferencias, width = Inf)

## REVISAR SI SON COMPLETED O RETURNED

detalle_montos_inconsistentes %>%
  count(
    status,
    name = "transacciones"
  ) %>%
  mutate(
    porcentaje =
      round(
        100 * transacciones / sum(transacciones),
        2
      )
  )

transactions %>%
  count(
    status,
    name = "total_transacciones"
  ) %>%
  mutate(
    porcentaje =
      round(
        100 * total_transacciones /
          sum(total_transacciones),
        2
      )
  )

# ============================================================
# 3. UNICIDAD
# ============================================================

duplicados_transaction_id <- transactions %>%
  filter(!is.na(transaction_id)) %>%
  count(
    transaction_id,
    name = "cantidad"
  ) %>%
  filter(cantidad > 1)

aud_unicidad <- tibble(
    total_transacciones =
    nrow(transactions),
    transaction_id_nulos =
    sum(is.na(transactions$transaction_id)),
    transaction_id_duplicados =
    nrow(duplicados_transaction_id),
    filas_involucradas =
    sum(duplicados_transaction_id$cantidad),
    filas_excedentes =
    sum(duplicados_transaction_id$cantidad - 1)
)
print(aud_unicidad, width = Inf)

# ============================================================
# 4. VALIDEZ
# ============================================================

aud_total_amount <- transactions %>%
  summarise(
    total_transacciones = n(),
    
    monto_negativo =
      sum(total_amount < 0, na.rm = TRUE),
    
    monto_cero =
      sum(total_amount == 0, na.rm = TRUE),
    
    monto_positivo =
      sum(total_amount > 0, na.rm = TRUE),
    
    pct_monto_cero =
      round(
        100 * monto_cero / total_transacciones,
        4
      )
  )

print(aud_total_amount, width = Inf)

# DETALLE DE TRANSACCIONES CON TOTAL_AMOUNT = 0

detalle_total_cero <- transactions %>%
  filter(total_amount == 0) %>%
  select(
    transaction_id,
    customer_id,
    transaction_date,
    store_id,
    total_amount,
    payment_method,
    loyalty_card,
    status
  )

print(detalle_total_cero)


# DETALLE DE ITEMS DE TRANSACCIONES CON TOTAL_AMOUNT = 0

detalle_total_cero_items <- transactions %>%
  filter(total_amount == 0) %>%
  select(
    transaction_id,
    total_amount,
    status
  ) %>%
  left_join(
    transaction_items,
    by = "transaction_id"
  ) %>%
  mutate(
    monto_linea = quantity * unit_price
  )

print(detalle_total_cero_items)


# 4 VALIDACIÓN DE UNIT_PRICE = 0 SIN PROMOCIÓN

aud_precio_cero <- transaction_items %>%
  summarise(
    total_items = n(),
    
    precio_cero_sin_promo =
      sum(
        unit_price == 0 &
          was_on_promo == FALSE,
        na.rm = TRUE
      ),
    
    pct_precio_cero_sin_promo =
      round(
        100 *
          precio_cero_sin_promo /
          total_items,
        4
      )
  )

print(aud_precio_cero, width = Inf)


# DETALLE DE PRECIOS CERO SIN PROMOCIÓN

detalle_precio_cero <- transaction_items %>%
  filter(
    unit_price == 0,
    was_on_promo == FALSE
  )

aud_precio_cero_detalle <- detalle_precio_cero %>%
  summarise(
    lineas_afectadas = n(),
    
    transacciones_afectadas =
      n_distinct(transaction_id),
    
    productos_afectados =
      n_distinct(item_id),
    
    unidades_afectadas =
      sum(quantity, na.rm = TRUE)
  )

print(aud_precio_cero_detalle, width = Inf)


# DISTRIBUCIÓN DE PRECIOS CERO POR PRODUCTO

aud_precio_cero_producto <- detalle_precio_cero %>%
  count(
    item_id,
    sort = TRUE,
    name = "casos_precio_cero"
  ) %>%
  left_join(
    products %>%
      select(
        item_id,
        item_name,
        brand,
        vendor_id,
        category,
        department,
        cost
      ),
    by = "item_id"
  ) %>%
  mutate(
    porcentaje_casos =
      round(
        100 *
          casos_precio_cero /
          sum(casos_precio_cero),
        2
      )
  )

print(aud_precio_cero_producto, width = Inf)

# PRODUCTO ITEM_089 - COMPORTAMIENTO HISTÓRICO DEL PRECIO

aud_item089 <- transaction_items %>%
  filter(item_id == "ITEM_089") %>%
  summarise(
    total_lineas = n(),
    
    precio_cero =
      sum(unit_price == 0, na.rm = TRUE),
    
    precio_cero_sin_promo =
      sum(
        unit_price == 0 &
          was_on_promo == FALSE,
        na.rm = TRUE
      ),
    
    precio_positivo =
      sum(unit_price > 0, na.rm = TRUE),
    
    pct_precio_cero =
      round(
        100 *
          precio_cero /
          total_lineas,
        2
      ),
    
    precio_minimo =
      min(unit_price, na.rm = TRUE),
    
    precio_promedio =
      mean(unit_price, na.rm = TRUE),
    
    mediana_precio =
      median(unit_price, na.rm = TRUE),
    
    precio_maximo =
      max(unit_price, na.rm = TRUE)
  )

print(aud_item089, width = Inf)

# INFORMACIÓN DE ITEM_089


info_item089 <- products %>%
  filter(item_id == "ITEM_089") %>%
  select(
    item_id,
    item_name,
    brand,
    vendor_id,
    category,
    department,
    cost
  )

print(info_item089)

# RELACIÓN ENTRE PRECIOS CERO Y CONSISTENCIA DE MONTOS

precio_cero_vs_consistencia <- detalle_precio_cero %>%
  select(
    transaction_id,
    transaction_item_id,
    item_id,
    quantity,
    unit_price,
    was_on_promo
  ) %>%
  left_join(
    consistencia_montos %>%
      select(
        transaction_id,
        total_amount,
        monto_calculado_items,
        diferencia_monto,
        diferencia_absoluta,
        coincide
      ),
    by = "transaction_id"
  )

# RESUMEN: PRECIOS CERO VS. CONSISTENCIA

aud_precio_cero_consistencia <- precio_cero_vs_consistencia %>%
  count(
    coincide,
    name = "lineas"
  ) %>%
  mutate(
    porcentaje =
      round(
        100 *
          lineas /
          sum(lineas),
        2
      )
  )

print(aud_precio_cero_consistencia)

# MAGNITUD DE DIFERENCIAS EN CASOS QUE TAMBIÉN SON INCONSISTENTES

aud_precio_cero_inconsistente <- precio_cero_vs_consistencia %>%
  filter(!coincide) %>%
  summarise(
    transacciones =
      n_distinct(transaction_id),
    
    diferencia_promedio =
      mean(diferencia_absoluta, na.rm = TRUE),
    
    mediana_diferencia =
      median(diferencia_absoluta, na.rm = TRUE),
    
    diferencia_maxima =
      max(diferencia_absoluta, na.rm = TRUE),
    
    pct_sobre_inconsistencias =
      round(
        100 *
          transacciones /
          aud_consistencia$no_coinciden,
        2
      )
  )

print(aud_precio_cero_inconsistente, width = Inf)

# ============================================================
# 5. INTEGRIDAD REFERENCIAL
# ============================================================

# TRANSACTIONS.STORE_ID -> STORES.STORE_ID

transacciones_tienda_inexistente <- transactions %>%
  anti_join(
    stores,
    by = "store_id"
  )

aud_fk_stores <- transacciones_tienda_inexistente %>%
  summarise(
    total_transacciones =
      nrow(transactions),
    
    filas_afectadas =
      n(),
    
    tiendas_inexistentes =
      n_distinct(store_id),
    
    pct_transacciones_afectadas =
      round(
        100 * filas_afectadas / total_transacciones,
        4
      )
  )

print(aud_fk_stores, width = Inf)

# 5.2 PRODUCTS.VENDOR_ID -> VENDORS.VENDOR_ID

productos_vendor_inexistente <- products %>%
  anti_join(
    vendors,
    by = "vendor_id"
  )

aud_fk_vendors <- productos_vendor_inexistente %>%
  summarise(
    total_productos =
      nrow(products),
    
    filas_afectadas =
      n(),
    
    vendors_inexistentes =
      n_distinct(vendor_id),
    
    pct_productos_afectados =
      round(
        100 * filas_afectadas / total_productos,
        4
      )
  )

print(aud_fk_vendors, width = Inf)

# DETALLE DE PRODUCTOS SIN PROVEEDOR

detalle_vendor_inexistente <- productos_vendor_inexistente %>%
  select(
    item_id,
    item_name,
    vendor_id,
    category,
    department,
    cost
  )

print(detalle_vendor_inexistente)

# IMPACTO DE PRODUCTOS CON VENDOR INEXISTENTE

impacto_vendor_inexistente <- transaction_items %>%
  semi_join(
    productos_vendor_inexistente,
    by = "item_id"
  ) %>%
  mutate(
    gmv_detalle =
      quantity * unit_price
  ) %>%
  summarise(
    lineas_afectadas =
      n(),
    
    transacciones_afectadas =
      n_distinct(transaction_id),
    
    productos_afectados =
      n_distinct(item_id),
    
    unidades =
      sum(quantity, na.rm = TRUE),
    
    gmv_detalle =
      sum(gmv_detalle, na.rm = TRUE),
    
    pct_lineas_afectadas =
      round(
        100 *
          lineas_afectadas /
          nrow(transaction_items),
        2
      ),
    
    pct_transacciones_afectadas =
      round(
        100 *
          transacciones_afectadas /
          nrow(transactions),
        2
      )
  )

print(
  impacto_vendor_inexistente,
  width = Inf
)


# ============================================================
# 6. FRESCURA
# ============================================================

fecha_inicio_dataset <- min(
  transactions$transaction_date,
  na.rm = TRUE
)

fecha_fin_dataset <- max(
  transactions$transaction_date,
  na.rm = TRUE
)

# CALENDARIO DE OPERACIÓN POR TIENDA

tiendas_calendario <- stores %>%
  select(
    store_id,
    opening_date
  ) %>%
  mutate(
    fecha_inicio = pmax(
      opening_date,
      fecha_inicio_dataset
    )
  )


calendario_tiendas <- do.call(
  rbind,
  lapply(
    seq_len(nrow(tiendas_calendario)),
    function(i) {
      
      data.frame(
        store_id =
          tiendas_calendario$store_id[i],
        
        transaction_date =
          seq(
            from = tiendas_calendario$fecha_inicio[i],
            to = fecha_fin_dataset,
            by = "day"
          )
      )
    }
  )
)

# TRANSACCIONES DIARIAS POR TIENDA

ventas_diarias <- transactions %>%
  group_by(
    store_id,
    transaction_date
  ) %>%
  summarise(
    transacciones =
      n_distinct(transaction_id),
    
    .groups = "drop"
  )


calendario_ventas <- calendario_tiendas %>%
  left_join(
    ventas_diarias,
    by = c(
      "store_id",
      "transaction_date"
    )
  ) %>%
  mutate(
    tiene_venta =
      !is.na(transacciones)
  )

# DETECTAR GAPS CONSECUTIVOS

gaps_tiendas <- calendario_ventas %>%
  group_by(store_id) %>%
  arrange(
    transaction_date,
    .by_group = TRUE
  ) %>%
  mutate(
    grupo_gap =
      cumsum(tiene_venta)
  ) %>%
  filter(!tiene_venta) %>%
  group_by(
    store_id,
    grupo_gap
  ) %>%
  summarise(
    fecha_inicio_gap =
      min(transaction_date),
    
    fecha_fin_gap =
      max(transaction_date),
    
    dias_sin_ventas =
      n(),
    
    .groups = "drop"
  ) %>%
  select(-grupo_gap) %>%
  arrange(
    desc(dias_sin_ventas)
  )

# RESUMEN

aud_frescura <- gaps_tiendas %>%
  summarise(
    cantidad_gaps = n(),
    
    tiendas_con_gap =
      n_distinct(store_id),
    
    gap_maximo_dias =
      max(dias_sin_ventas, na.rm = TRUE),
    
    gaps_3_dias_o_mas =
      sum(dias_sin_ventas >= 3)
  )

print(
  aud_frescura,
  width = Inf
)

# DETALLE DEL GAP

detalle_gaps_tiendas <- gaps_tiendas %>%
  left_join(
    stores %>%
      select(
        store_id,
        store_name,
        country,
        city,
        format,
        region,
        opening_date
      ),
    by = "store_id"
  )

print(
  detalle_gaps_tiendas,
  width = Inf
)

# CONTEXTO: 7 DÍAS ANTES Y DESPUÉS

aud_gap_contexto <- gaps_tiendas %>%
  select(
    store_id,
    fecha_inicio_gap,
    fecha_fin_gap
  ) %>%
  left_join(
    calendario_ventas,
    by = "store_id"
  ) %>%
  filter(
    transaction_date >= fecha_inicio_gap - 7,
    transaction_date <= fecha_fin_gap + 7
  ) %>%
  mutate(
    periodo = case_when(
      transaction_date < fecha_inicio_gap ~
        "7 días antes",
      
      transaction_date > fecha_fin_gap ~
        "7 días después",
      
      TRUE ~
        "Gap"
    )
  ) %>%
  group_by(
    store_id,
    periodo
  ) %>%
  summarise(
    dias = n(),
    
    dias_con_ventas =
      sum(tiene_venta),
    
    transacciones_totales =
      sum(
        coalesce(transacciones, 0)
      ),
    
    transacciones_promedio_dia =
      mean(
        coalesce(transacciones, 0)
      ),
    
    .groups = "drop"
  )

print(
  aud_gap_contexto,
  width = Inf
)

# ============================================================
# 7. INTEGRIDAD TEMPORAL
# ============================================================

transacciones_antes_apertura <- transactions %>%
  inner_join(
    stores %>%
      select(
        store_id,
        store_name,
        opening_date
      ),
    by = "store_id"
  ) %>%
  filter(
    transaction_date < opening_date
  )

# RESUMEN

aud_integridad_temporal <- transacciones_antes_apertura %>%
  summarise(
    filas_afectadas = n(),
    
    tiendas_afectadas =
      n_distinct(store_id)
  )

print(
  aud_integridad_temporal,
  width = Inf
)

# DETALLE DE CASOS ENCONTRADOS

detalle_integridad_temporal <- transacciones_antes_apertura %>%
  mutate(
    dias_antes_apertura =
      as.integer(
        opening_date - transaction_date
      )
  ) %>%
  select(
    transaction_id,
    store_id,
    store_name,
    transaction_date,
    opening_date,
    dias_antes_apertura,
    total_amount,
    status
  ) %>%
  arrange(
    store_id,
    transaction_date
  )

print(
  detalle_integridad_temporal,
  n = 20
)

# RESUMEN POR TIENDA

aud_integridad_temporal_detalle <- detalle_integridad_temporal %>%
  group_by(
    store_id,
    store_name,
    opening_date
  ) %>%
  summarise(
    transacciones_afectadas = n(),
    
    primera_transaccion =
      min(transaction_date),
    
    ultima_transaccion =
      max(transaction_date),
    
    max_dias_antes_apertura =
      max(dias_antes_apertura),
    
    .groups = "drop"
  )

print(
  aud_integridad_temporal_detalle,
  width = Inf
)

# ============================================================
# 8. A/B TEST
# ============================================================

promo_control <- store_promotions %>%
  filter(
    variant == "CONTROL",
    !is.na(start_date),
    !is.na(end_date)
  ) %>%
  select(
    store_id,
    promo_name,
    control_inicio = start_date,
    control_fin = end_date
  )


promo_treatment <- store_promotions %>%
  filter(
    variant == "TREATMENT",
    !is.na(start_date),
    !is.na(end_date)
  ) %>%
  select(
    store_id,
    promo_name,
    treatment_inicio = start_date,
    treatment_fin = end_date
  )

# VALIDAR SUPERPOSICIÓN ENTRE CONTROL Y TREATMENT

ab_conflictos <- promo_control %>%
  inner_join(
    promo_treatment,
    by = c(
      "store_id",
      "promo_name"
    ),
    relationship = "many-to-many"
  ) %>%
  filter(
    control_inicio <= treatment_fin,
    treatment_inicio <= control_fin
  ) %>%
  mutate(
    inicio_solapamiento =
      pmax(
        control_inicio,
        treatment_inicio
      ),
    
    fin_solapamiento =
      pmin(
        control_fin,
        treatment_fin
      )
  ) %>%
  distinct(
    store_id,
    promo_name,
    control_inicio,
    control_fin,
    treatment_inicio,
    treatment_fin,
    inicio_solapamiento,
    fin_solapamiento
  )

# RESUMEN

aud_ab_test <- ab_conflictos %>%
  summarise(
    conflictos = n(),
    
    tiendas_afectadas =
      n_distinct(store_id),
    
    promociones_afectadas =
      n_distinct(promo_name)
  )

print(
  aud_ab_test,
  width = Inf
)

# DETALLE DE CONFLICTOS

detalle_ab_conflictos <- ab_conflictos %>%
  arrange(
    promo_name,
    store_id
  )

print(
  detalle_ab_conflictos,
  width = Inf
)

# INFORMACIÓN DE LAS TIENDAS AFECTADAS

detalle_ab_conflictos_tienda <- detalle_ab_conflictos %>%
  left_join(
    stores %>%
      select(
        store_id,
        store_name,
        country,
        format,
        size_sqm,
        region
      ),
    by = "store_id"
  ) %>%
  select(
    store_id,
    store_name,
    country,
    format,
    size_sqm,
    region,
    promo_name,
    control_inicio,
    control_fin,
    treatment_inicio,
    treatment_fin,
    inicio_solapamiento,
    fin_solapamiento
  )

print(
  detalle_ab_conflictos_tienda,
  width = Inf
)