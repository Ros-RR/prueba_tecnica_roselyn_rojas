# ============================================================
# CARGA DE DATOS A DUCKDB
# ============================================================

library(DBI)
library(duckdb)
library(here)

# Cargar los seis datasets ya tipados
source(
  here::here(
    "R",
    "01_ingesta.R"
  )
)

# 1. CREAR CONEXIÓN

con_sql <- dbConnect(
  duckdb::duckdb(),
  dbdir = here::here(
    "data",
    "retail.duckdb"
  )
)


# 2. CARGAR TABLAS

dbWriteTable(
  con_sql,
  "transactions",
  transactions,
  overwrite = TRUE
)

dbWriteTable(
  con_sql,
  "transaction_items",
  transaction_items,
  overwrite = TRUE
)

dbWriteTable(
  con_sql,
  "stores",
  stores,
  overwrite = TRUE
)

dbWriteTable(
  con_sql,
  "products",
  products,
  overwrite = TRUE
)

dbWriteTable(
  con_sql,
  "vendors",
  vendors,
  overwrite = TRUE
)

dbWriteTable(
  con_sql,
  "store_promotions",
  store_promotions,
  overwrite = TRUE
)

# 3. VALIDAR TABLAS CREADAS

print(
  dbListTables(con_sql)
)


# 4. VALIDAR CANTIDAD DE REGISTROS


conteos_sql <- dbGetQuery(
  con_sql,
  "
  SELECT
      'transactions' AS tabla,
      COUNT(*) AS registros
  FROM transactions

  UNION ALL

  SELECT
      'transaction_items',
      COUNT(*)
  FROM transaction_items

  UNION ALL

  SELECT
      'stores',
      COUNT(*)
  FROM stores

  UNION ALL

  SELECT
      'products',
      COUNT(*)
  FROM products

  UNION ALL

  SELECT
      'vendors',
      COUNT(*)
  FROM vendors

  UNION ALL

  SELECT
      'store_promotions',
      COUNT(*)
  FROM store_promotions;
  "
)

print(conteos_sql)


# 5. VALIDAR RANGO DE FECHAS


validacion_fechas <- dbGetQuery(
  con_sql,
  "
  SELECT
      MIN(transaction_date) AS fecha_minima,
      MAX(transaction_date) AS fecha_maxima
  FROM transactions;
  "
)

print(validacion_fechas)


message("Carga a DuckDB finalizada correctamente.")

