## INGESTA DE DATOS

source(here::here("R", "00_config.R"))

## CARGAR LOS 6 ARCHIVOS 

transactions <- read_csv(
  file = file.path(PATH_RAW, "transactions.csv"),
  col_types = tipos_transactions,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "NULL")
)

transaction_items <- read_csv(
  file = file.path(PATH_RAW, "transaction_items.csv"),
  col_types = tipos_transaction_items,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "NULL")
)

stores <- read_csv(
  file = file.path(PATH_RAW, "stores.csv"),
  col_types = tipos_stores,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "NULL")
)

products <- read_csv(
  file = file.path(PATH_RAW, "products.csv"),
  col_types = tipos_products,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "NULL")
)

vendors <- read_csv(
  file = file.path(PATH_RAW, "vendors.csv"),
  col_types = tipos_vendors,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "NULL")
)

store_promotions <- read_csv(
  file = file.path(PATH_RAW, "store_promotions.csv"),
  col_types = tipos_store_promotions,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "NULL")
)

## CONVERTIR LAS VARIABLES FECHAS EN FORMATO FECHA

transactions <- transactions %>%
  mutate(
    transaction_date = ymd(transaction_date)
  )

stores <- stores %>%
  mutate(
    opening_date = ymd(opening_date)
  )

store_promotions <- store_promotions %>%
  mutate(
    start_date = ymd(start_date),
    end_date = ymd(end_date)
  )

