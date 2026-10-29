# Decisiones técnicas

## Streaming y procesamiento por ejecución

Bronze utiliza Auto Loader para incorporar archivos nuevos.
Silver procesa las líneas desde Bronze mediante lectura streaming.

El Job se ejecuta bajo demanda y el pipeline está configurado
con continuous: false. Cada actualización procesa la información
pendiente y termina.

La prueba inicial de repetición conservó 676,933 filas con los
mismos archivos y checkpoints.

## Materialized views

Las vistas materializadas agrupan las líneas por pedido y generan
los indicadores diarios, mensuales y comparables entre años.

Permiten consultar resultados preparados sin reconstruir las
transformaciones manualmente en cada análisis.

El modo de actualización depende de la consulta y del plan elegido
por Databricks; no se supone que todas las vistas sean incrementales.

## Expectations y validaciones

Las expectations registran problemas de calidad en las tablas.
Se conservan las líneas para mantener su trazabilidad.

El notebook de validación ejecuta diez comprobaciones sobre
conservación de filas, campos críticos, unicidad, conciliación de
conteos e importes y presencia de los archivos esperados en Bronze.

El Job marca error si alguna comprobación falla.

Los pedidos cuyo importe no puede resolverse se conservan en
silver_orders y también aparecen en silver_orders_review.

## Evaluación de Liquid Clustering

Medición de la base completa:

- bronze_pos_raw: 483.25 MiB y 12 archivos Delta.
- silver_pos_lines: 798.82 MiB y 12 archivos Delta.
- Ambas reportan clusteringColumns = [].

Decisión: mantener la organización actual, dado el tamaño observado
y la cantidad reducida de archivos.

Si aumentan el volumen o las consultas por fecha y tienda,
se evaluará clustering sobre fecha y store_number, comparando
tiempos y archivos leídos bajo condiciones equivalentes.

Esta evaluación inicial no demuestra una mejora de rendimiento
mediante clustering.

## Manejo de fallos

Se probó un fallo controlado en revisar_archivos mediante
simular_fallo = true.

Se verificó el mensaje del fallo y se reparó la ejecución con
simular_fallo = false. Las tres tareas finalizaron correctamente.

El valor normal del parámetro es false.