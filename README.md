# Prueba Técnica — Analista Sr. de Datos

## Autor

**Nombre:** Roselyn Rojas Rodríguez  
**Herramientas:** R, SQL y Power BI

---

## 1. Descripción

Este repositorio contiene la solución de la prueba técnica para el puesto
de Analista Sr. de Datos. 

El caso analiza 18 meses de información transaccional de una cadena de
retail multiformato con presencia en cinco países de Centroamérica.

---

## 2. Tecnologías utilizadas

- R
- RStudio
- SQL
- DuckDB
- Power BI
- Git y GitHub
- R Markdown
- renv

---

## 3. Estructura del repositorio

```text
data/raw/                    Archivos CSV originales
data/processed/              Datos preparados para análisis y Power BI
R/                           Scripts reutilizables
docs/                        Documentación técnica
bloque3_visualizaciones/     Visualizaciones exportadas
```

Los entregables principales se encuentran en la raíz del repositorio.

---

## 4. Datos de entrada

Los siguientes archivos deben estar ubicados en `data/raw/`:

```text
transactions.csv
transaction_items.csv
stores.csv
products.csv
vendors.csv
store_promotions.csv
```

Los archivos originales no deben modificarse directamente.

---

## 5. Requisitos

- R: R version 4.6.1
- RStudio
- Power BI Desktop
- Git

Para restaurar las dependencias de R:

```r
renv::restore()
```

---

## 6. Orden de ejecución

El orden previsto de ejecución es:

```text
R/00_config.R
R/01_ingesta.R
R/02_auditoria_calidad.R
R/03_transformaciones.R
R/04_metricas.R
R/05_analisis_exploratorio.R
R/06_ab_test.R
R/07_export_powerbi.R
```

Este orden podrá ajustarse conforme avance el desarrollo.

---

## 7. Entregables

- `bloque0_auditoria.md`
- `bloque1_queries.sql`
- `bloque2_modelo.pdf`
- `bloque2_decisiones.md`
- `bloque3_analisis.html`
- `bloque3_visualizaciones/`
- `bloque4_kpi_framework.md`
- `bloque5_dashboard.pbix`
- `bloque5_presentacion_EN.pdf`

---

## 8. Supuestos y decisiones metodológicas

Los supuestos utilizados para el cálculo de GMV, Comp Sales, cohortes,
GMROI, posibles quiebres de inventario y el experimento A/B se documentan
en:

```text
docs/definicion_metricas.md
```

---

## 9. Uso de inteligencia artificial

Se utilizaron herramientas de inteligencia artificial como apoyo para:

- Organización inicial del proyecto.
- Revisión de código.
- Discusión de alternativas metodológicas.
- Revisión de redacción y documentación.

El detalle de prompts, resultados generados, modificaciones propias y
validaciones manuales se encuentra en:

```text
docs/registro_uso_ia.md
```

Todo resultado analítico y estadístico será validado manualmente antes de
incorporarlo a los entregables finales.