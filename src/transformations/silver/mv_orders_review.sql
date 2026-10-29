CREATE OR REFRESH MATERIALIZED VIEW silver_orders_review
COMMENT 'Pedidos pendientes de revisión del importe comparable.'
AS
SELECT *
FROM silver_orders
WHERE importe_comparable IS NULL;