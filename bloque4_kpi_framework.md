
# Bloque 4 - Framework de KPIs

## Objetivo

Definir un conjunto reducido de KPIs para monitorear un programa de
mejora de productividad de tiendas, cubriendo productividad, experiencia
del cliente y desempeño de proveedor.

| KPI | Definición exacta | Fórmula | Frecuencia | Fuente de datos | Target sugerido | ¿Cómo detectar si el dato está mal? |
|----|----|----|----|----|----|----|
| **1. GMV por m²** | Mide cuánto GMV genera cada tienda por metro cuadrado disponible. | `GMV neto / size_sqm` | Semanal | `transactions`, `stores` | Crecimiento ≥ 5% vs. período comparable | Validar `size_sqm > 0`, ausencia de duplicados y consistencia de GMV |
| **2. Ticket promedio** | Valor promedio generado por transacción completada. | `GMV neto / número de transacciones` | Semanal | `transactions` | Crecimiento ≥ 3% | Detectar tickets nulos, negativos o variaciones extremas frente al histórico |
| **3. Tasa de retención M1** | Porcentaje de clientes de una cohorte que regresan al mes siguiente. | `Clientes activos en M1 / tamaño de cohorte × 100` | Mensual | `transactions` | ≥ 70% | Validar `customer_id`, cohortes incompletas y períodos todavía no observables |
| **4. Disponibilidad comercial estimada** *(Leading Indicator)* | Mide la proporción de SKUs sin señales de ausencia prolongada de ventas. | `1 - (SKUs con gap relevante / SKUs activos)` | Diario / Semanal | `transaction_items`, `transactions`, `products` | ≥ 98% | Comparar con frecuencia histórica de venta; alertar si todos los SKUs presentan gaps simultáneamente |
| **5. GMROI de proveedor** | Mide el margen generado por cada unidad monetaria de costo asociada al proveedor. | `(GMV - costo total) / costo total` | Mensual | `transaction_items`, `products`, `vendors` | ≥ 1.0 | Validar costos nulos/cero, vendors inexistentes y precios anómalos |
| **6. Índice de Productividad Integral** *(KPI compuesto)* | Resume productividad, cliente y proveedor en una sola métrica ejecutiva. | `40% GMV/m² + 30% Retención M1 + 30% GMROI`, usando cada componente normalizado contra su target | Mensual | KPIs 1, 3 y 5 | ≥ 100% del target compuesto | Validar que los tres componentes estén disponibles, actualizados y bajo la misma ventana temporal |

## North Star Metric

La **North Star Metric** propuesta es **GMV por m²**.

Se selecciona porque representa de forma directa la productividad
económica de cada tienda y permite comparar establecimientos de
distintos tamaños y formatos.

Además, conecta el objetivo principal del programa, mejorar la
productividad de tiendas, con una métrica simple, accionable y
comparable en el tiempo.
