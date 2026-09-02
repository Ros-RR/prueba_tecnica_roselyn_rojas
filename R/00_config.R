## CONFIGURACIONES
# ============================================================

## 1- LLAMAR LIBRERIAS

library(readr)
library(dplyr)
library(purrr)
library(tibble)
library(lubridate)
library(janitor)
library(here)

options(
  stringsAsFactors = FALSE,
  scipen = 999
)

## 2- RUTAS USADAS

PATH_RAW <- here("data", "raw")
PATH_PROCESSED <- here("data", "processed")

# Crear carpeta processed si no existe
if (!dir.exists(PATH_PROCESSED)) {
  dir.create(PATH_PROCESSED, recursive = TRUE)
}

message("Configuración cargada correctamente")

## 3- ESQUEMA DE ARCHIVOS 

## Los archivos se leen sin modificar los CSV originales.
## Se definen explícitamente los tipos para controlar la interpretación
## de separadores, valores numéricos, booleanos y fechas.

## DEFINIR LOS TIPOS DE VARIABLES

## A- TRANSACTIONS

tipos_transactions <- cols(
  transaction_id   = col_character(),
  customer_id      = col_character(),
  transaction_date = col_character(),
  store_id         = col_character(),
  total_amount     = col_double(),
  payment_method   = col_character(),
  loyalty_card     = col_logical(),
  status           = col_character()
)

## B- TRANSACTIONS ITEMS

tipos_transaction_items <- cols(
  transaction_item_id = col_character(),
  transaction_id      = col_character(),
  item_id             = col_character(),
  quantity            = col_integer(),
  unit_price          = col_double(),
  was_on_promo        = col_logical()
)

## C- STORES

tipos_stores <- cols(
  store_id     = col_character(),
  store_name   = col_character(),
  country      = col_character(),
  city         = col_character(),
  format       = col_character(),
  size_sqm     = col_integer(),
  opening_date = col_character(),
  region       = col_character()
)

## D- PRODUCTS

tipos_products <- cols(
  item_id    = col_character(),
  item_name  = col_character(),
  brand      = col_character(),
  vendor_id  = col_character(),
  category   = col_character(),
  department = col_character(),
  cost       = col_double()
)

## E- VENDORS

tipos_vendors <- cols(
  vendor_id         = col_character(),
  vendor_name       = col_character(),
  country           = col_character(),
  tier              = col_character(),
  is_shared_catalog = col_logical()
)

## F- STORE PROMOTIONS

tipos_store_promotions <- cols(
  store_id   = col_character(),
  promo_name = col_character(),
  variant    = col_character(),
  start_date = col_character(),
  end_date   = col_character(),
  promo_type = col_character()
)

