# Registro de Uso de Inteligencia Artificial

Este documento registra los principales usos de herramientas de inteligencia
artificial durante el desarrollo de la prueba técnica.

La inteligencia artificial se utilizó como apoyo para la organización del
proyecto, revisión de código, discusión metodológica y mejora de documentación.
Las decisiones finales, ejecución de los procesos y validación de resultados
fueron realizadas manualmente.

| Fecha | Herramienta | Prompt u objetivo | Resultado generado | Modificaciones realizadas | Validación manual |
|---|---|---|---|---|---|
| 2026-09-01 | ChatGPT | Apoyo en definir una estructura reproducible para desarrollar la prueba utilizando R, SQL, DuckDB, Git y renv | Propuesta de estructura del repositorio, organización de scripts, README, configuración de Git y manejo de dependencias | Se ajustaron nombres, rutas y orden de ejecución de acuerdo con el flujo utilizado durante la prueba | Verificación de estructura en RStudio, ejecución de scripts, restauración de dependencias y sincronización con GitHub |
| 2026-09-01 | ChatGPT | Revisar el proceso de auditoría de calidad de los seis archivos fuente | Propuesta de ajustes para completitud, consistencia, unicidad, validez, integridad referencial, frescura, integridad temporal y conflictos de promociones | Se adaptaron las validaciones a los campos y hallazgos reales de los datasets y se definieron decisiones de tratamiento para cada caso | Ejecución de validaciones en R, revisión de conteos, registros afectados y consistencia de resultados |
| 2026-09-02 | ChatGPT | Revisar las seis consultas SQL solicitadas en el Bloque 1 | Propuestas de ajustes para Comp Sales, productividad por m², cohortes, GMROI, posibles quiebres de stock y análisis de promociones | Las consultas se adaptaron a DuckDB, se ajustaron supuestos de negocio y se corrigió el tratamiento de períodos no observables en cohortes | Ejecución individual de cada consulta en DuckDB y revisión de resultados |
| 2026-09-02 | ChatGPT | Revisar la reproducibilidad y documentación técnica del Bloque 1 | Recomendaciones para documentar el motor SQL, dependencias, carga de datos y criterios generales de las consultas | Se actualizaron `README.md`, `bloque1_queries.sql` y el flujo de carga mediante `R/03_carga_sql.R` | Reconstrucción de la base DuckDB desde los CSV originales y verificación de las consultas |
| 2026-09-02 | ChatGPT | Ajustar un modelo dimensional para BigQuery que soporte los análisis solicitados | Propuesta de Star Schema con tablas de hechos y dimensiones, manejo de clientes no identificados, historial de tiendas y proveedores no encontrados | Se revisaron nombres, granularidad, campos clave y decisiones de modelado | Validación del modelo contra los requerimientos del caso y la estructura de los datasets fuente |
| 2026-09-02 | ChatGPT | Revisar y mejorar las respuestas del Bloque 2 sobre diseño de pipeline ETL/ELT y gobernanza | Recomendaciones sobre datos tardíos, monitoreo de tiendas, cargas incrementales, frecuencia del pipeline, protección de `customer_id`, Data Ownership y reconciliación de GMV | Se simplificó y ajustó la redacción, conservando las decisiones consideradas adecuadas para el caso | Verificación punto por punto contra las secciones B y C de la prueba |
| 2026-09-02 | ChatGPT | Revisar el análisis exploratorio y experimento A/B del Bloque 3 | Propuestas de análisis de estacionalidad, Pareto de categorías, cohortes, posibles quiebres, hallazgo libre y evaluación estadística del experimento | Se ajustaron los análisis a los datos observados, se corrigieron períodos parciales, se validaron supuestos y se adaptaron las interpretaciones | Ejecución de análisis en R y revisión de resultados, gráficos, p-values e intervalos de confianza |
| 2026-09-02 | ChatGPT | Validar y ajustar los indicadores propuestos para el framework de KPIs del programa de productividad de tiendas | Revisión de seis KPIs, cobertura de productividad, experiencia del cliente y desempeño de proveedor, además de leading indicator, KPI compuesto y North Star Metric | Se ajustaron definiciones, fórmulas, targets, controles de calidad y redacción para mantener el framework compacto y alineado con la prueba | Revisión manual de cada indicador contra los requisitos del Bloque 4 y los análisis desarrollados previamente |

## Criterio de uso

Las respuestas generadas por inteligencia artificial no se incorporaron de
forma automática a los entregables.

El proceso seguido fue:

1. Utilizar la IA para generar propuestas o revisar una solución.
2. Adaptar la propuesta al contexto y a los datos reales de la prueba.
3. Ejecutar el código o proceso correspondiente.
4. Validar manualmente los resultados.
5. Incorporar únicamente la versión revisada al entregable final.

La responsabilidad por las decisiones metodológicas y los resultados
presentados corresponde a la autora de la solución.