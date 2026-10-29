CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_kpis
COMMENT 'Indicadores mensuales con cobertura de tiendas, fechas e importes.'
AS
SELECT
    TRUNC(fecha, 'MM') AS mes,
    MIN(fecha) AS primera_fecha,
    MAX(fecha) AS ultima_fecha,
    COUNT(DISTINCT store_number) AS tiendas,
    COUNT(DISTINCT fecha) AS dias_con_datos,
    COUNT(*) AS tienda_dias_con_actividad,

    SUM(pedidos) AS pedidos,

    ROUND(
        1.0 * SUM(pedidos) / COUNT(*),
        2
    ) AS pedidos_por_tienda_dia,

    SUM(pedidos_con_importe) AS pedidos_con_importe,
    SUM(pedidos_sin_importe) AS pedidos_sin_importe,

    ROUND(
        100.0 * SUM(pedidos_con_importe)
        / NULLIF(SUM(pedidos), 0),
        2
    ) AS cobertura_importe_pct,

    SUM(importe_estimado) AS importe_estimado,

    ROUND(
        SUM(importe_estimado)
        / NULLIF(SUM(pedidos_con_importe), 0),
        2
    ) AS importe_promedio_por_pedido,

    ROUND(
        100.0 * SUM(pedidos_con_descuento)
        / NULLIF(SUM(pedidos_con_dato_descuento), 0),
        2
    ) AS pedidos_con_descuento_pct

FROM gold_store_daily
GROUP BY TRUNC(fecha, 'MM');