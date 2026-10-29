from pyspark import pipelines as dp
from pyspark.sql import functions as F


CLAVE_PEDIDO = [
    "store_number",
    "fecha",
    "check_number",
    "begin_time",
]


@dp.materialized_view(
    name="silver_orders_base",
    comment="Un registro por pedido, con sumas y controles de consistencia."
)
@dp.expect(
    "total_unico_por_pedido",
    "total_distintos = 1"
)
def silver_orders_base():

    lineas = spark.read.table("silver_pos_lines")

    # Las líneas sin clave completa permanecen en Silver,
    # pero no se pueden asignar de forma confiable a un pedido.
    clave_completa = (
        F.col("store_number").isNotNull()
        & F.col("fecha").isNotNull()
        & F.col("check_number").isNotNull()
        & F.col("begin_time").isNotNull()
    )

    validas = lineas.filter(clave_completa)

    no_es_void = F.col("transaction_type") != "Void"

    item_no_anulado = F.col("item_voided_n") == 0

    linea_incompleta = (
        F.col("transaction_type").isNull()
        | F.col("menu_price_n").isNull()
        | F.col("quantity_n").isNull()
        | F.col("item_voided_n").isNull()
    )

    agregados = [
        F.count("*").alias("lineas"),
        F.min("hora").alias("hora"),
        F.countDistinct("source_file").alias("archivos_distintos"),

        # Excluir líneas cuyo tipo es Void.
        F.sum(
            F.when(
                no_es_void,
                F.col("importe_linea")
            ).otherwise(0)
        ).alias("suma_lineas"),

        # Excluir también artículos marcados como anulados.
        F.sum(
            F.when(
                no_es_void & item_no_anulado,
                F.col("importe_linea")
            ).otherwise(0)
        ).alias("suma_no_anuladas"),

        F.sum(
            F.when(linea_incompleta, 1).otherwise(0)
        ).alias("lineas_incompletas"),

        F.sum(
            F.when(
                F.col("error_conversion_numerica"),
                1
            ).otherwise(0)
        ).alias("lineas_con_error_numerico"),
    ]

    # Comprobar los campos que se repiten dentro del pedido.
    for origen, nombre in [
        ("total_n", "total"),
        ("tax_n", "impuesto"),
        ("total_discount_n", "descuento"),
    ]:
        agregados.extend([
            F.countDistinct(origen).alias(f"{nombre}_distintos"),
            F.min(origen).alias(f"{nombre}_valor"),
            F.sum(
                F.when(F.col(origen).isNull(), 1).otherwise(0)
            ).alias(f"{nombre}_nulos"),
        ])

    return validas.groupBy(*CLAVE_PEDIDO).agg(*agregados)