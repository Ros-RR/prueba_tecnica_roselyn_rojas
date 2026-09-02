# Bloque 5 - Propuesta de Dashboard y Presentación Ejecutiva

## Estado del bloque

Por limitación de tiempo no se completó la implementación final del dashboard en Power BI ni la presentación ejecutiva en PDF.

Este documento describe cómo se construiría el Bloque 5, incluyendo el diseño del dashboard, las métricas, la lógica de interacción, las alertas y la estructura propuesta de la presentación ejecutiva.

---

# Parte A - Dashboard operativo

## 1. Objetivo

Construir una única página operativa en Power BI que pueda ser utilizada diariamente por un gerente regional sin soporte técnico.

El diseño priorizaría:

- lectura rápida;
- filtros simples;
- alertas visibles;
- comparación temporal;
- navegación mínima;
- métricas consistentes con los bloques anteriores.

---

## 2. Modelo de datos propuesto

El dashboard utilizaría principalmente:

- `transactions`
- `transaction_items`
- `stores`
- `products`
- resultados de cohortes del Bloque 3
- resultados de posibles quiebres del Bloque 3

Relaciones principales:

```text
stores[store_id] 1 ---- * transactions[store_id]

transactions[transaction_id] 1 ---- * transaction_items[transaction_id]

products[item_id] 1 ---- * transaction_items[item_id]
```

Se incorporaría además una dimensión calendario para análisis semanal, mensual y comparaciones contra períodos anteriores.

---

## 3. Diseño de la página

La página se organizaría en cuatro niveles.

### Nivel 1 - Filtros

Filtros visibles en la parte superior:

- País
- Formato
- Región
- Rango de fechas

Todos los visuales responderían a estos filtros.

### Nivel 2 - KPIs principales

Se mostrarían cuatro tarjetas:

1. GMV neto
2. Número de transacciones
3. Ticket promedio
4. GMV por m²

Cada tarjeta incluiría:

- valor actual;
- variación porcentual contra la semana anterior;
- indicador visual de mejora o deterioro.

### Nivel 3 - Desempeño de tiendas

Se incluirían:

- ranking de tiendas dentro de su formato;
- tendencia de Comp Sales;
- alerta de tiendas bajo el percentil 25 de GMV por m².

Las tiendas bajo P25 se marcarían en rojo para facilitar la identificación de problemas operativos.

### Nivel 4 - Cliente y disponibilidad

Se incluirían:

- heatmap de retención por cohorte;
- tabla de posibles quiebres de stock;
- duración del gap;
- categoría;
- producto;
- tienda;
- GMV potencial asociado.

---

## 4. Métricas principales

### GMV neto

```text
COMPLETED = + total_amount
RETURNED  = - total_amount
```

### Número de transacciones

Cantidad distinta de `transaction_id`.

### Ticket promedio

```text
GMV neto / número de transacciones
```

### GMV por m²

```text
GMV neto / size_sqm
```

### Variación semanal

```text
(Valor semana actual - Valor semana anterior)
/
Valor semana anterior
```

### Comp Sales

Comparación del GMV del período actual contra el mismo período del año anterior, utilizando únicamente tiendas comparables.

### Alerta P25

Para cada formato se calcularía el percentil 25 de GMV por m².

```text
GMV/m² < P25 del formato -> BAJO_RENDIMIENTO
```

---

## 5. Visuales propuestos

| Sección | Visual |
|---|---|
| GMV neto | Tarjeta KPI |
| Transacciones | Tarjeta KPI |
| Ticket promedio | Tarjeta KPI |
| GMV/m² | Tarjeta KPI |
| Comp Sales | Gráfico de líneas |
| Ranking de tiendas | Barras horizontales |
| Alerta P25 | Tabla / barras con formato condicional |
| Cohortes | Heatmap |
| Stock | Tabla ordenada por duración del gap |

---

## 6. Comportamiento esperado

El gerente podría seleccionar, por ejemplo:

```text
País: Costa Rica
Formato: HIPERMERCADO
Región: Todas
Fecha: último trimestre
```

y visualizar inmediatamente:

- GMV y variación semanal;
- tiendas con mejor y peor productividad;
- tendencia comparable contra el año anterior;
- tiendas bajo el nivel esperado;
- comportamiento de retención;
- posibles riesgos de disponibilidad.

El dashboard se diseñaría para que la información crítica pudiera entenderse sin necesidad de navegar entre múltiples páginas.

---

# Parte B - Executive Presentation

La presentación se desarrollaría en inglés, con un máximo de cinco slides y lenguaje simple orientado al VP de Operaciones.

## Slide 1 - Executive Summary

**Title:** Executive Summary

- EXPRESS is the most volatile store format.
- Electronics, Home and Clothing generate about 84% of GMV.
- Customer retention drops mainly in the first month.
- The A/B test did not show a statistically significant GMV improvement.

**Key message:** Focus on store productivity, early customer retention and better operational signals.

---

## Slide 2 - Store Performance

**Title:** Store Performance

- EXPRESS showed the highest weekly GMV variability.
- GMV per m² should be used as the main productivity metric.
- Stores below the 25th percentile should receive operational review.

**Suggested visual:** GMV/m² ranking by store and format.

---

## Slide 3 - Opportunities

**Title:** Key Opportunities

- Improve performance of low-productivity stores.
- Focus commercial actions on Electronics and Home.
- Strengthen customer retention during the first month.
- Review low-GMROI vendors and categories.

**Suggested visual:** Category mix + retention curve.

---

## Slide 4 - Risks

**Title:** Main Risks

- Potential stock-out signals are very frequent and require inventory validation.
- Retention falls sharply after the first purchase.
- Data quality issues can affect some analytical outputs.
- A/B test groups were not fully balanced by store size.

**Suggested visual:** Risk summary with severity indicators.

---

## Slide 5 - Recommendations

**Title:** Recommendations

1. Monitor GMV/m² weekly and review stores below P25.
2. Create a first-month retention action plan.
3. Add inventory and replenishment data to improve stock-out detection.
4. Repeat the merchandising experiment with better-balanced stores.
5. Use a certified GMV definition across all management reports.

**Key message:** Improve productivity through focused store actions, better retention and stronger data controls.

---

# Conclusión

El Bloque 5 se implementaría como una solución ejecutiva de una sola página en Power BI, complementada por una presentación de cinco slides en inglés.

El diseño reutilizaría las métricas y hallazgos desarrollados en los Bloques 1 a 4, manteniendo consistencia en las definiciones de GMV, productividad, retención, desempeño de proveedores y posibles quiebres.

La principal prioridad de implementación sería asegurar que el gerente regional pueda identificar rápidamente qué tiendas requieren atención, por qué y qué acción tomar.
