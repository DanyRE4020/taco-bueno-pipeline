# Evidencias de ejecución

Resultados observados en las ejecuciones compartidas de Databricks.

| Comprobación | Resultado |
|---|---:|
| CSV inventariados | 597 |
| CSV con datos | 573 |
| CSV con solo encabezado | 24 |
| Filas en Bronze | 85,273,331 |
| Pedidos identificados | 13,788,668 |
| Tiendas en la base completa | 119 |
| Pedidos con importe comparable | 13,626,754 |
| Cobertura del importe | 98.83 % |
| Pedidos pendientes de importe | 161,914 |
| Tiendas en la comparación entre años | 109 |
| Pares de tienda y fecha | 23,235 |
| Cambio en pedidos por tienda-día | −5.32 % |

El Job completo terminó correctamente en una ejecución de
8 minutos y 45 segundos. Este tiempo corresponde a esa corrida.

La prueba inicial con cinco archivos mantuvo 676,933 filas
después de repetir la ejecución.

También se comprobó el fallo controlado del inventario y
la recuperación mediante Repair run.

Bronze y Silver tenían 12 archivos Delta cada una, con tamaños
de 483.25 MiB y 798.82 MiB, respectivamente. Se evaluó Liquid
Clustering y se decidió conservar la organización actual.
No se realizó una comparación de rendimiento con clustering.

## Análisis por tienda

- 109 tiendas comparadas: 91 disminuyeron y 18 crecieron.
- El 83.49 % de las tiendas presentó una disminución.
- Las diez tiendas con mayores pérdidas acumularon 96,959 pedidos
  menos y concentraron el 31.40 % de las pérdidas de las 91
  tiendas que disminuyeron.
- El balance de las 109 tiendas, incluyendo las que crecieron,
  fue de 276,569 pedidos menos.

## Prueba de transformaciones de Silver

Se ejecutó un pipeline separado con ocho registros inventados.

Se conservaron las ocho filas. Las comprobaciones automáticas
aprobaron los dos casos válidos y los seis casos con problemas:
tienda vacía, fecha inválida, cantidad no numérica, precio faltante,
hora de inicio inválida y hora de fin inválida.