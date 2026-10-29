CREATE OR REFRESH MATERIALIZED VIEW gold_yoy_store_day
COMMENT 'Pares de tienda y fecha presentes en ambos años, febrero a septiembre.'
AS
SELECT
    anterior.store_number,
    anterior.fecha AS fecha_2025,
    actual.fecha AS fecha_2026,
    MONTH(actual.fecha) AS mes_numero,

    anterior.pedidos AS pedidos_2025,
    actual.pedidos AS pedidos_2026,

    anterior.pedidos_con_importe AS con_importe_2025,
    actual.pedidos_con_importe AS con_importe_2026,

    anterior.importe_estimado AS importe_estimado_2025,
    actual.importe_estimado AS importe_estimado_2026

FROM gold_store_daily anterior

INNER JOIN gold_store_daily actual
    ON anterior.store_number = actual.store_number
    AND ADD_MONTHS(anterior.fecha, 12) = actual.fecha

WHERE anterior.fecha BETWEEN DATE '2025-02-01'
                         AND DATE '2025-09-27'
  AND actual.fecha BETWEEN DATE '2026-02-01'
                       AND DATE '2026-09-27';