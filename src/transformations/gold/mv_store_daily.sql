CREATE OR REFRESH MATERIALIZED VIEW gold_store_daily
COMMENT 'Actividad diaria por tienda e importes estimados con su cobertura.'
AS

SELECT
    store_number,
    fecha,

    COUNT(*) AS pedidos,

    COUNT(importe_comparable) AS pedidos_con_importe,

    SUM(
        CASE
            WHEN importe_comparable IS NULL THEN 1
            ELSE 0
        END
    ) AS pedidos_sin_importe,

    ROUND(
        100.0 * COUNT(importe_comparable) / COUNT(*),
        2
    ) AS cobertura_importe_pct,

    SUM(importe_comparable) AS importe_estimado,

    AVG(importe_comparable) AS importe_promedio,

    percentile_approx(
        CAST(importe_comparable AS DOUBLE),
        0.5,
        10000
    ) AS importe_mediano,

    COUNT(importe_comparable_estricto) AS pedidos_estrictos,

    SUM(
        importe_comparable_estricto
    ) AS importe_estimado_estricto,

    SUM(
        CASE WHEN con_descuento = 1 THEN 1 ELSE 0 END
    ) AS pedidos_con_descuento,

    COUNT(con_descuento) AS pedidos_con_dato_descuento

FROM silver_orders

-- Misma base de actividad del EDA: Total único por pedido.
WHERE total_distintos = 1

GROUP BY
    store_number,
    fecha;