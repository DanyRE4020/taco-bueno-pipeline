CREATE OR REFRESH MATERIALIZED VIEW silver_orders
COMMENT 'Pedidos con regla de Total, importe comparable estimado y marcas de calidad.'
AS

-- Recuperar los valores que son únicos dentro del pedido.
WITH campos AS (
    SELECT
        *,

        CASE
            WHEN total_distintos = 1 THEN total_valor
        END AS total,

        CASE
            WHEN impuesto_distintos = 1 THEN impuesto_valor
            WHEN impuesto_distintos = 0
                THEN CAST(0 AS DECIMAL(20,4))
        END AS impuesto,

        CASE
            WHEN descuento_distintos = 1 THEN descuento_valor
            WHEN descuento_distintos = 0
                THEN CAST(0 AS DECIMAL(20,4))
        END AS descuento,

        impuesto_distintos = 0 AS impuesto_imputado,
        descuento_distintos = 0 AS descuento_imputado,

        (
            total_distintos = 1
            AND impuesto_distintos <= 1
            AND descuento_distintos <= 1
        ) AS campos_consistentes

    FROM silver_orders_base
),

-- Probar las fórmulas con tolerancia de dos centavos.
coincidencias AS (
    SELECT
        *,

        COALESCE(
            ABS(total - suma_lineas) <= 0.02,
            FALSE
        ) AS coincide_a,

        COALESCE(
            ABS(total - (suma_lineas + impuesto)) <= 0.02
            OR ABS(
                total - (suma_lineas + impuesto - descuento)
            ) <= 0.02
            OR ABS(
                total - (suma_no_anuladas + impuesto)
            ) <= 0.02
            OR ABS(
                total - (suma_no_anuladas + impuesto - descuento)
            ) <= 0.02,
            FALSE
        ) AS coincide_b

    FROM campos
),

-- Clasificar cada pedido antes de estimar su importe.
clasificados AS (
    SELECT
        *,

        CASE
            WHEN NOT campos_consistentes
                THEN 'inconsistente'

            WHEN lineas_con_error_numerico > 0
                THEN 'error_numerico'

            WHEN lineas_incompletas > 0
                THEN 'lineas_incompletas'

            WHEN coincide_a AND coincide_b
                 AND ABS(impuesto - descuento) <= 0.02
                THEN 'ambigua_compatible'

            WHEN coincide_a AND coincide_b
                THEN 'ambigua'

            WHEN coincide_a
                THEN 'A_sin_impuesto'

            WHEN coincide_b
                THEN 'B_con_impuesto'

            ELSE 'no_cuadra'
        END AS regla_total,

        (
            campos_consistentes
            AND total_nulos = 0
            AND impuesto_nulos = 0
            AND descuento_nulos = 0
            AND lineas_incompletas = 0
            AND lineas_con_error_numerico = 0
        ) AS campos_completos

    FROM coincidencias
),

importes AS (
    SELECT
        *,

        CASE
            WHEN regla_total = 'A_sin_impuesto'
                THEN total - descuento

            WHEN regla_total IN (
                'B_con_impuesto',
                'ambigua_compatible'
            )
                THEN total - impuesto
        END AS importe_comparable

    FROM clasificados
)

SELECT
    *,

    -- Escenario de sensibilidad que exige campos completos.
    CASE
        WHEN campos_completos THEN importe_comparable
    END AS importe_comparable_estricto,

    YEAR(fecha) AS anio,
    TRUNC(fecha, 'MM') AS mes,

    CASE
        WHEN descuento IS NOT NULL
            THEN CASE WHEN descuento > 0 THEN 1 ELSE 0 END
    END AS con_descuento

FROM importes;