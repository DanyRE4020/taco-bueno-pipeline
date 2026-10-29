from functools import reduce

from pyspark import pipelines as dp
from pyspark.sql import functions as F


NULOS_TEXTO = ["", "na", "n/a", "null", "none", "nan"]

COLUMNAS_NUMERICAS = [
    "total",
    "tax",
    "total_discount",
    "menu_price",
    "quantity",
    "item_discount",
    "item_voided",
    "order_voided",
]

COLUMNAS_TEXTO = [
    "store_number",
    "check_number",
    "begin_time",
    "end_time",
    "transaction_type",
    "menu_item",
    "pos_code",
    "pop",
    "report_group",
    "tender_type",
]


def limpiar_texto(nombre):
    texto = F.trim(F.col(nombre))

    return F.when(
        F.lower(texto).isin(NULOS_TEXTO),
        F.lit(None).cast("string")
    ).otherwise(texto)


def convertir_hora(nombre):
    return F.expr(
        f"""
        try_to_timestamp(
            concat('2000-01-01 ', upper(trim(`{nombre}`))),
            'yyyy-MM-dd h:mm a'
        )
        """
    )


REGLAS = {
    "clave_completa": """
        store_number IS NOT NULL
        AND check_number IS NOT NULL
        AND begin_time IS NOT NULL
        AND fecha IS NOT NULL
    """,
    "hora_inicio_interpretable": "hora_inicio IS NOT NULL",
    "hora_fin_interpretable": """
        end_time IS NULL OR hora_fin IS NOT NULL
    """,
    "conversion_numerica_correcta": "NOT error_conversion_numerica",
    "campos_para_importes_completos": """
        total_n IS NOT NULL
        AND tax_n IS NOT NULL
        AND total_discount_n IS NOT NULL
        AND menu_price_n IS NOT NULL
        AND quantity_n IS NOT NULL
        AND item_voided_n IS NOT NULL
    """,
    "sin_datos_rescatados": "_rescued_data IS NULL",
}


@dp.table(
    name="silver_pos_lines",
    comment="Líneas POS con tipos convertidos y controles de calidad."
)
@dp.expect_all(REGLAS)
def silver_pos_lines():

    datos = spark.readStream.table("bronze_pos_raw")

    # Limpiar textos sin modificar la tabla Bronze.
    for columna in COLUMNAS_TEXTO:
        if columna in datos.columns:
            datos = datos.withColumn(
                columna,
                limpiar_texto(columna)
            )

    # Interpretar los formatos de fecha usados en el EDA.
    datos = datos.withColumn(
        "fecha",
        F.coalesce(
            F.expr("try_to_timestamp(trim(date), 'M/d/yyyy')"),
            F.expr("try_to_timestamp(trim(date), 'yyyy-MM-dd')")
        ).cast("date")
    )

    # Conservar las horas originales y agregar su versión convertida.
    datos = (
        datos
        .withColumn("hora_inicio", convertir_hora("begin_time"))
        .withColumn("hora_fin", convertir_hora("end_time"))
        .withColumn("hora", F.hour("hora_inicio"))
    )

    # Agregar columnas numéricas; los valores originales se conservan.
    for columna in COLUMNAS_NUMERICAS:
        datos = datos.withColumn(
            f"{columna}_n",
            F.expr(
                f"try_cast(trim(`{columna}`) AS DECIMAL(20,4))"
            )
        )

    # Detectar texto presente que no pudo convertirse a número.
    errores = [
        (
            F.col(columna).isNotNull()
            & ~F.lower(F.trim(F.col(columna))).isin(NULOS_TEXTO)
            & F.col(f"{columna}_n").isNull()
        )
        for columna in COLUMNAS_NUMERICAS
    ]

    datos = datos.withColumn(
        "error_conversion_numerica",
        reduce(lambda a, b: a | b, errores)
    )

    # Si falta precio o cantidad, el importe permanece nulo.
    datos = datos.withColumn(
        "importe_linea",
        F.col("menu_price_n") * F.col("quantity_n")
    )

    return datos