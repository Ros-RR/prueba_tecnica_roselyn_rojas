# ============================================================
# BLOQUE 3 - PARTE B
# EXPERIMENTO A/B
# ============================================================

library(dplyr)
library(lubridate)
library(here)

source(
  here::here(
    "R",
    "01_ingesta.R"
  )
)

# PARAMETROS DEL EXPERIMENTO

EXPERIMENTO <- "Exhibicion_Q3_2024"

FECHA_INICIO_TEST <- as.Date("2024-09-01")
FECHA_FIN_TEST    <- as.Date("2024-10-12")

# 6 semanas inmediatamente anteriores al experimento
FECHA_INICIO_PRE <- FECHA_INICIO_TEST - days(42)
FECHA_FIN_PRE    <- FECHA_INICIO_TEST - days(1)

# ============================================================
# 1. ASIGNACIONES DEL EXPERIMENTO
# ============================================================

asignaciones_exp <- store_promotions %>%
  filter(
    promo_name == EXPERIMENTO,
    start_date <= FECHA_FIN_TEST,
    end_date >= FECHA_INICIO_TEST
  ) %>%
  select(
    store_id,
    variant,
    start_date,
    end_date
  ) %>%
  distinct()

# DETECTAR TIENDAS ASIGNADAS A AMBOS GRUPOS

resumen_asignacion <- asignaciones_exp %>%
  group_by(
    store_id
  ) %>%
  summarise(
    cantidad_variantes =
      n_distinct(variant),
    
    inicio_asignacion =
      min(start_date),
    
    fin_asignacion =
      max(end_date),
    
    .groups = "drop"
  )

tiendas_conflicto <- resumen_asignacion %>%
  filter(
    cantidad_variantes > 1
  )

print(
  tiendas_conflicto
)

# ASIGNACION VALIDA

asignacion_valida <- asignaciones_exp %>%
  anti_join(
    tiendas_conflicto,
    by = "store_id"
  ) %>%
  group_by(
    store_id
  ) %>%
  summarise(
    variant = first(variant),
    
    inicio_asignacion =
      min(start_date),
    
    fin_asignacion =
      max(end_date),
    
    .groups = "drop"
  ) %>%
  filter(
    inicio_asignacion <= FECHA_INICIO_TEST,
    fin_asignacion >= FECHA_FIN_TEST
  )

print(
  asignacion_valida
)

# CANTIDAD DE TIENDAS POR GRUPO

cantidad_tiendas_grupo <- asignacion_valida %>%
  count(
    variant,
    name = "tiendas"
  )

print(
  cantidad_tiendas_grupo
)

# GMV BASE - 6 SEMANAS ANTES DEL TEST

gmv_pre_tienda <- transactions %>%
  filter(
    transaction_date >= FECHA_INICIO_PRE,
    transaction_date <= FECHA_FIN_PRE
  ) %>%
  mutate(
    gmv_neto = case_when(
      status == "COMPLETED" ~ total_amount,
      status == "RETURNED"  ~ -total_amount,
      TRUE                  ~ 0
    )
  ) %>%
  group_by(
    store_id
  ) %>%
  summarise(
    gmv_pre = sum(
      gmv_neto,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

# BASE PARA VALIDAR COMPARABILIDAD

base_balance <- asignacion_valida %>%
  left_join(
    gmv_pre_tienda,
    by = "store_id"
  ) %>%
  mutate(
    gmv_pre =
      coalesce(
        gmv_pre,
        0
      ),
    
    gmv_pre_semanal =
      gmv_pre / 6
  ) %>%
  inner_join(
    stores %>%
      select(
        store_id,
        country,
        format,
        size_sqm
      ),
    by = "store_id"
  )

# RESUMEN DE BALANCE

balance_general <- base_balance %>%
  group_by(
    variant
  ) %>%
  summarise(
    tiendas = n(),
    
    gmv_base_semanal_promedio =
      mean(gmv_pre_semanal),
    
    gmv_base_semanal_mediana =
      median(gmv_pre_semanal),
    
    size_sqm_promedio =
      mean(size_sqm),
    
    size_sqm_mediana =
      median(size_sqm),
    
    .groups = "drop"
  )

print(
  balance_general
)

# BALANCE DE FORMATOS

balance_formato <- base_balance %>%
  count(
    variant,
    format,
    name = "tiendas"
  ) %>%
  group_by(
    variant
  ) %>%
  mutate(
    participacion_pct =
      100 *
      tiendas /
      sum(tiendas)
  ) %>%
  ungroup()


print(
  balance_formato,
  n = Inf
)

# PRUEBA DE BALANCE - GMV BASE

prueba_balance_gmv <- t.test(
  gmv_pre_semanal ~ variant,
  data = base_balance
)

print(
  prueba_balance_gmv
)

# PRUEBA DE BALANCE - TAMAÑO DE TIENDA

prueba_balance_tamano <- t.test(
  size_sqm ~ variant,
  data = base_balance
)

print(
  prueba_balance_tamano
)

# PRUEBA DE BALANCE - FORMATO
tabla_formato <- table(
  base_balance$format,
  base_balance$variant
)

prueba_balance_formato <- fisher.test(
  tabla_formato
)

print(
  prueba_balance_formato
)


# ============================================================
# 2. RESULTADO EN GMV
# ============================================================

# GMV SEMANAL POR TIENDA DURANTE EL TEST

gmv_test_semanal_base <- transactions %>%
  filter(
    transaction_date >= FECHA_INICIO_TEST,
    transaction_date <= FECHA_FIN_TEST
  ) %>%
  mutate(
    semana_test =
      as.integer(
        transaction_date - FECHA_INICIO_TEST
      ) %/% 7 + 1,
    
    gmv_neto = case_when(
      status == "COMPLETED" ~ total_amount,
      status == "RETURNED"  ~ -total_amount,
      TRUE                  ~ 0
    )
  ) %>%
  group_by(
    store_id,
    semana_test
  ) %>%
  summarise(
    gmv_semanal = sum(
      gmv_neto,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

# ASEGURAR 6 SEMANAS POR TIENDA

grilla_test <- merge(
  asignacion_valida %>%
    select(
      store_id,
      variant
    ),
  
  data.frame(
    semana_test = 1:6
  ),
  
  by = NULL
) %>%
  as_tibble()

gmv_test_semanal <- grilla_test %>%
  left_join(
    gmv_test_semanal_base,
    by = c(
      "store_id",
      "semana_test"
    )
  ) %>%
  mutate(
    gmv_semanal =
      coalesce(
        gmv_semanal,
        0
      )
  )

# VALIDAR CANTIDAD DE SEMANAS

validacion_semanas_test <- gmv_test_semanal %>%
  count(
    store_id,
    variant,
    name = "semanas"
  )

print(
  validacion_semanas_test,
  n = Inf
)

# PROMEDIO SEMANAL POR TIENDA

gmv_test_tienda <- gmv_test_semanal %>%
  group_by(
    store_id,
    variant
  ) %>%
  summarise(
    gmv_semanal_promedio =
      mean(gmv_semanal),
    
    .groups = "drop"
  )

# RESUMEN POR GRUPO
resultado_gmv_grupo <- gmv_test_tienda %>%
  group_by(
    variant
  ) %>%
  summarise(
    tiendas = n(),
    
    gmv_promedio =
      mean(gmv_semanal_promedio),
    
    desviacion =
      sd(gmv_semanal_promedio),
    
    mediana =
      median(gmv_semanal_promedio),
    
    .groups = "drop"
  )

print(
  resultado_gmv_grupo
)

# T-TEST DE WELCH

gmv_treatment_vector <- gmv_test_tienda %>%
  filter(
    variant == "TREATMENT"
  ) %>%
  pull(
    gmv_semanal_promedio
  )

gmv_control_vector <- gmv_test_tienda %>%
  filter(
    variant == "CONTROL"
  ) %>%
  pull(
    gmv_semanal_promedio
  )

test_gmv <- t.test(
  x = gmv_treatment_vector,
  y = gmv_control_vector,
  var.equal = FALSE,
  conf.level = 0.95
)

print(
  test_gmv
)

# DIFERENCIA Y UPLIFT

gmv_control <- mean(
  gmv_control_vector
)

gmv_treatment <- mean(
  gmv_treatment_vector
)

diferencia_gmv <-
  gmv_treatment -
  gmv_control

uplift_gmv_pct <-
  100 *
  diferencia_gmv /
  gmv_control

resultado_efecto_gmv <- tibble(
  gmv_control =
    gmv_control,
  
  gmv_treatment =
    gmv_treatment,
  
  diferencia_absoluta =
    diferencia_gmv,
  
  uplift_pct =
    uplift_gmv_pct,
  
  p_value =
    test_gmv$p.value,
  
  ic_95_inferior =
    test_gmv$conf.int[1],
  
  ic_95_superior =
    test_gmv$conf.int[2]
)

print(
  resultado_efecto_gmv
)

# SENSIBILIDAD: CAMBIO VS. PERIODO PREVIO
# Debido al desbalance en tamaño de tienda, se compara también
# el cambio de cada tienda respecto a su propio GMV base.

sensibilidad_gmv <- gmv_test_tienda %>%
  left_join(
    base_balance %>%
      select(
        store_id,
        gmv_pre_semanal
      ),
    by = "store_id"
  ) %>%
  mutate(
    cambio_vs_pre =
      gmv_semanal_promedio -
      gmv_pre_semanal,
    
    cambio_vs_pre_pct =
      100 *
      cambio_vs_pre /
      gmv_pre_semanal
  )

resumen_sensibilidad <- sensibilidad_gmv %>%
  group_by(
    variant
  ) %>%
  summarise(
    cambio_promedio_pct =
      mean(
        cambio_vs_pre_pct,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  )

print(
  resumen_sensibilidad
)


# ============================================================
# 3. RESULTADO EN TICKET Y FRECUENCIA
# ============================================================

# METRICAS POR TIENDA DURANTE EL TEST

metricas_test_tienda <- transactions %>%
  filter(
    transaction_date >= FECHA_INICIO_TEST,
    transaction_date <= FECHA_FIN_TEST,
    status == "COMPLETED"
  ) %>%
  inner_join(
    asignacion_valida %>%
      select(
        store_id,
        variant
      ),
    by = "store_id"
  ) %>%
  group_by(
    store_id,
    variant
  ) %>%
  summarise(
    transacciones =
      n_distinct(transaction_id),
    
    gmv =
      sum(
        total_amount,
        na.rm = TRUE
      ),
    
    ticket_promedio =
      gmv / transacciones,
    
    .groups = "drop"
  ) %>%
  mutate(
    transacciones_semanales =
      transacciones / 6
  )

# RESUMEN POR GRUPO

resultado_ticket_frecuencia <- metricas_test_tienda %>%
  group_by(
    variant
  ) %>%
  summarise(
    ticket_promedio =
      mean(ticket_promedio),
    
    transacciones_semanales =
      mean(transacciones_semanales),
    
    .groups = "drop"
  )

print(
  resultado_ticket_frecuencia
)

# T-TEST TICKET

test_ticket <- t.test(
  ticket_promedio ~ variant,
  data = metricas_test_tienda,
  var.equal = FALSE
)

print(
  test_ticket
)

# T-TEST FRECUENCIA

test_frecuencia <- t.test(
  transacciones_semanales ~ variant,
  data = metricas_test_tienda,
  var.equal = FALSE
)

print(
  test_frecuencia
)
