# Prueba Técnica — Analista Sr. de Datos

## Autor

**Nombre:** Roselyn Rojas Rodríguez  
**Herramientas:** R, SQL, DuckDB y Power BI

---

## 1. Descripción

Este repositorio contiene la solución de la prueba técnica para el puesto
de Analista Sr. de Datos.

El caso analiza 18 meses de información transaccional de una cadena de
retail multiformato con presencia en cinco países de Centroamérica.

La solución incluye procesos de auditoría de calidad, análisis SQL,
modelado de datos, análisis exploratorio, evaluación de experimentos A/B,
definición de KPIs y construcción de visualizaciones ejecutivas.

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

DuckDB se utiliza como motor SQL local para ejecutar y validar de forma
reproducible las consultas del Bloque 1.

---

## 3. Estructura del repositorio

```text
data/
├── raw/                     Archivos CSV originales
└── processed/               Datos preparados para análisis y Power BI

R/
├── 00_config.R              Configuración, rutas y tipos de datos
├── 01_ingesta.R             Lectura y tipado de los archivos CSV
├── 02_auditoria_calidad.R   Auditoría de calidad de datos
└── 03_carga_sql.R           Creación y carga de la base DuckDB

docs/                        Documentación técnica
bloque3_visualizaciones/     Visualizaciones exportadas

bloque0_auditoria.Rmd
bloque0_auditoria.md
bloque1_queries.sql