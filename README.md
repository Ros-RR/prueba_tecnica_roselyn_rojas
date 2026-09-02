# Prueba Técnica — Analista Sr. de Datos

## Autor

**Nombre:** Roselyn Rojas Rodríguez  
**Herramientas:** R, SQL, DuckDB, Git y GitHub

---

## 1. Descripción

Este repositorio contiene la solución desarrollada para la prueba técnica
del puesto de Analista Sr. de Datos.

El caso analiza 18 meses de información transaccional de una cadena de
retail multiformato con presencia en cinco países de Centroamérica.

La solución desarrollada comprende:

- Auditoría de calidad de datos
- Análisis SQL avanzado
- Modelado dimensional y diseño de pipeline
- Análisis exploratorio
- Experimentación A/B
- Definición de un framework de KPIs

---

## 2. Tecnologías utilizadas

- R
- RStudio
- SQL
- DuckDB
- Git y GitHub
- R Markdown
- renv

DuckDB se utiliza como motor SQL local para ejecutar y validar de forma
reproducible las consultas del Bloque 1.

---

## 3. Estructura del repositorio

```text
data/
└── raw/
    ├── products.csv
    ├── store_promotions.csv
    ├── stores.csv
    ├── transaction_items.csv
    ├── transactions.csv
    └── vendors.csv

R/
├── 00_config.R
├── 01_ingesta.R
├── 02_auditoria_calidad.R
├── 03_carga_sql.R
├── 04_analisis_exploratorio.R
└── 05_ab_test.R

docs/
└── registro_uso_ia.md

bloque3_visualizaciones/
├── 01_gmv_semanal_formato.png
├── 02_pareto_categorias_formato.png
├── 03_retencion_cohortes.png
├── 04_ticket_clientes_retenidos.png
├── 05_quiebres_stock_categoria.png
└── 06_ticket_lealtad_formato.png

bloque0_auditoria.Rmd
bloque0_auditoria.md
bloque1_queries.sql
bloque2_modelo.pdf
bloque2_decisiones.md
bloque3_analisis.Rmd
bloque3_analisis.html
bloque4_kpi_framework.Rmd
bloque4_kpi_framework.md

renv.lock
prueba_tecnica_roselyn_rojas.Rproj
README.md