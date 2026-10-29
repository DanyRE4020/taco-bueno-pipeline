# Taco Bueno · Pipeline de datos en Databricks

Pipeline que transforma archivos CSV del punto de venta en tablas
para analizar pedidos, importes estimados y descuentos.

## Objetivo

Automatizar la preparación de la base y producir resultados
reproducibles, con controles de calidad y trazabilidad hasta
el archivo de origen.

## Datos procesados

- 597 CSV: 573 con datos y 24 con solo encabezado.
- Tres estructuras: 19, 21 y 22 columnas.
- 85,273,331 líneas de actividad.
- 13,788,668 pedidos identificados.
- 119 identificadores de tienda.
- Fechas de negocio: 22 de enero de 2025 a 27 de septiembre de 2026.

Cada fila original representa actividad a nivel de producto.
Un pedido puede aparecer en varias filas.

La clave utilizada para agrupar pedidos es:
Store # + Date + Check Number + Begin Time.

## Organización del repositorio

| Carpeta | Contenido |
|---|---|
| resources/jobs | Configuración del Job y sus dependencias |
| resources/pipelines | Configuración del pipeline Lakeflow |
| src/transformations/bronze | Ingestión de los CSV |
| src/transformations/silver | Conversión de tipos y construcción de pedidos |
| src/transformations/gold | Indicadores y tablas para análisis |
| notebooks | Preparación, inventario, validación y análisis |
| docs | Decisiones técnicas |

Los CSV fuente se almacenan en un Volume de Databricks.

## Arquitectura

1. El inventario identifica los archivos, sus encabezados y su estado.
2. Bronze incorpora los registros con Auto Loader y conserva su origen.
3. Silver convierte tipos, registra problemas y agrupa las líneas por pedido.
4. Gold genera indicadores diarios, mensuales y comparaciones entre años.
5. El notebook de validación comprueba la consistencia de las tablas.

## Tablas principales

| Tabla | Propósito |
|---|---|
| audit_source_files | Historial de revisiones de los archivos recibidos |
| bronze_pos_raw | Líneas originales y metadatos del archivo |
| silver_pos_lines | Líneas con fechas, horas y números convertidos |
| silver_orders_base | Sumas y controles por pedido |
| silver_orders | Pedidos con clasificación del Total e importe comparable |
| silver_orders_review | Pedidos pendientes de resolver su importe |
| gold_store_daily | Indicadores por tienda y fecha |
| gold_order_quality_daily | Cobertura del importe por fecha |
| gold_monthly_kpis | Indicadores mensuales y cobertura |
| gold_yoy_store_day | Pares de tienda y fecha presentes en ambos años |
| gold_yoy_store_summary | Comparación por tienda para identificar crecimiento, disminución y concentración de las pérdidas de pedidos |

## Preparación y ejecución

1. Clonar el repositorio como Git folder en Databricks.
2. Ejecutar el notebook 00_preparacion para preparar el Volume.
3. Subir los CSV originales a:
   /Volumes/workspace/taco_bueno/archivos_fuente/
4. Crear el pipeline taco_bueno_etl con:
   - Código: src/transformations y sus subcarpetas.
   - Catálogo: workspace.
   - Esquema de salida: default.
   - Compute: Serverless.
   - Modo de ejecución: triggered.
5. Crear el Job taco_bueno_daily_job con estas dependencias:
   revisar_archivos → actualizar_pipeline → validar_datos.
6. Asociar revisar_archivos al notebook 04_inventario_archivos.
7. Asociar actualizar_pipeline al pipeline taco_bueno_etl.
8. Asociar validar_datos al notebook 03_validacion_pipeline.
9. Configurar simular_fallo = false.
10. Ejecutar el Job con Run now y revisar el estado de las tres tareas.

Las tareas posteriores utilizan la condición All succeeded.

El disparador implementado es manual. Para esta entrega se procesa
un conjunto histórico de archivos; una programación periódica se
evaluará cuando exista una recepción periódica de datos.

Los YAML exportados contienen rutas e identificadores del workspace
original. Al recrear el proyecto en otra cuenta, actualizar esas
referencias y el pipeline_id del Job.

## Actualizaciones y repeticiones

Agregar archivos nuevos con nombres originales y únicos.
Conservar los archivos ya procesados sin sustituirlos.

Usar actualizaciones normales y mantener Full refresh desactivado.
Los checkpoints del pipeline permiten continuar la ingestión.

El inventario agrega una revisión nueva por ejecución, identificada
mediante ejecucion_id. Por eso su historial crece aunque no lleguen
CSV nuevos.

La prueba inicial de repetición mantuvo las mismas 676,933 filas
con los mismos archivos y checkpoints.

## Calidad de datos

Se comprueban:

- Encabezados admitidos y archivos con solo encabezado.
- Presencia de los archivos con datos en Bronze.
- Conservación del número de filas entre Bronze y Silver.
- Claves completas y conversión de fechas, horas y números.
- Datos rescatados por el lector.
- Un único Total informado por pedido.
- Unicidad de tienda y fecha en Gold.
- Conservación de pedidos e importes entre Silver y Gold.
- Presencia de los pedidos pendientes en la tabla de revisión.

Las filas idénticas se conservan: la fuente no contiene un
identificador de línea que permita confirmar que son duplicados
erróneos. Los pedidos grandes, importes cero y valores negativos
también se conservan para su análisis.

Las expectations registran problemas durante el procesamiento.
El notebook de validación marca error si alguna comprobación falla.

## Interpretación de los importes

El Total no sigue la misma fórmula en toda la base.

El pipeline compara distintas fórmulas que consideran las líneas,
impuestos, descuentos y anulaciones, con tolerancia de 0.02.

El importe comparable es una estimación sin impuesto basada en esas
reglas. Los casos ambiguos o no conciliados conservan un importe nulo.

Cuando todo el impuesto o descuento del pedido está vacío, la regla
principal asume cero y marca la imputación. También se conserva un
importe estricto para evaluar ese supuesto.

No sumar directamente Total en las líneas originales: puede
repetirse dentro de un mismo pedido.

## Manejo de fallos

Para probar la orquestación, ejecutar el Job con simular_fallo = true.
El notebook de inventario genera un fallo controlado al inicio.

Verificar el mensaje y los estados de las tareas dependientes.
Para recuperar la ejecución, utilizar Repair run y establecer
simular_fallo = false.

Ante un fallo real, revisar primero la salida de la tarea y corregir
la causa. Las tablas escritas antes del fallo pueden seguir disponibles;
consultar el resultado de las validaciones antes de utilizar una carga.

## Resultados obtenidos

- Importe comparable estimable en 13,626,754 pedidos: 98.83 %.
- 161,914 pedidos conservados para revisión del importe.
- Comparación entre años: 109 tiendas y 23,235 pares de tienda-fecha.
- Periodo comparable: 1 de febrero a 27 de septiembre.
- Pedidos por tienda-día: 223.65 en 2025 y 211.75 en 2026.
- Cambio conjunto: −5.32 %.
- Mayores caídas mensuales: julio −8.63 % y septiembre −8.28 %.

Estos resultados permiten identificar periodos y tiendas para
investigar la disminución de pedidos. La comparación no identifica
por sí sola sus causas.

Los notebooks 05_analisis_resultados y 06_evaluacion_tecnica contienen
las visualizaciones y la evaluación técnica.

## Consideraciones

- Los pedidos no equivalen a clientes únicos.
- Los días sin registros no se interpretan como cero ventas.
- Se utiliza Date como fecha de negocio, sin desplazarla un día.
- La cobertura de tiendas y fechas cambia entre meses.
- La estimación del importe requiere validación con el responsable
  del sistema de origen para su uso contable.

Consultar docs/decisiones_tecnicas.md para las decisiones sobre
streaming, materialized views, expectations y Liquid Clustering.

## Alcance técnico
- Los YAML documentan la configuración del Job y del pipeline.
  La preparación descrita utiliza la interfaz de Databricks;
  todavía no se incluye un bundle de despliegue con databricks.yml.
- Los CSV deben colocarse directamente en el Volume indicado,
  conservando nombres únicos y sin reemplazar archivos procesados.
- La validación consulta el inventario más reciente.
  Las ejecuciones deben realizarse una después de otra.
- La prueba de fallo controlado verifica las dependencias y la
  recuperación del Job; no representa una prueba con CSV dañados.

  ## Pruebas de calidad de Silver

El pipeline taco_bueno_pruebas_calidad utiliza el mismo archivo
st_pos_lines.py del pipeline principal y un CSV con ocho casos
inventados: dos válidos y seis con problemas conocidos.

Para reproducir la prueba:

1. Ejecutar la celda de preparación de datos de
   notebooks/07_pruebas_calidad.
2. Crear el pipeline de pruebas tomando como referencia
   resources/pipelines/lakeflow_pruebas_calidad.yml.
   Adaptar las rutas al workspace utilizado.
3. Confirmar catálogo workspace y esquema taco_bueno_pruebas.
4. Ejecutar el pipeline de pruebas.
5. Ejecutar las celdas de consulta y comprobación del notebook 07.

Las comprobaciones verifican conservación de filas, interpretación
de fechas y horas, claves faltantes, conversiones numéricas
y conservación de importes nulos cuando faltan datos.

Los ocho casos produjeron los resultados esperados.
