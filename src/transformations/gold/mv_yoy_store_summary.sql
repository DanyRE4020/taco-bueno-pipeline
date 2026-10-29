CREATE OR REFRESH MATERIALIZED VIEW gold_yoy_store_summary
COMMENT 'Comparación de pedidos por tienda usando fechas presentes en ambos años.'
AS
SELECT
    store_number,

    COUNT(*) AS pares_tienda_fecha,

    SUM(pedidos_2025) AS pedidos_2025,
    SUM(pedidos_2026) AS pedidos_2026,

    SUM(pedidos_2026) - SUM(pedidos_2025)
        AS cambio_pedidos,

    ROUND(
        SUM(pedidos_2025) * 1.0 / COUNT(*),
        2
    ) AS pedidos_por_dia_2025,

    ROUND(
        SUM(pedidos_2026) * 1.0 / COUNT(*),
        2
    ) AS pedidos_por_dia_2026,

    ROUND(
        100.0
        * (SUM(pedidos_2026) - SUM(pedidos_2025))
        / NULLIF(SUM(pedidos_2025), 0),
        2
    ) AS cambio_pct

FROM gold_yoy_store_day

GROUP BY store_number;