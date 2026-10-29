CREATE OR REFRESH MATERIALIZED VIEW gold_order_quality_daily
COMMENT 'Cobertura y problemas del importe comparable por fecha.'
AS
SELECT
    fecha,
    COUNT(*) AS pedidos,
    COUNT(importe_comparable) AS pedidos_con_importe,

    SUM(
        CASE WHEN importe_comparable IS NULL THEN 1 ELSE 0 END
    ) AS pedidos_sin_importe,

    ROUND(
        100.0 * COUNT(importe_comparable) / COUNT(*),
        2
    ) AS cobertura_pct,

    COUNT(importe_comparable_estricto) AS pedidos_estrictos,

    SUM(
        CASE WHEN regla_total = 'ambigua' THEN 1 ELSE 0 END
    ) AS pedidos_ambiguos,

    SUM(
        CASE WHEN regla_total = 'no_cuadra' THEN 1 ELSE 0 END
    ) AS pedidos_no_cuadran

FROM silver_orders
GROUP BY fecha;