import re

from pyspark import pipelines as dp
from pyspark.sql import functions as F


RUTA_FUENTE = "/Volumes/workspace/taco_bueno/archivos_fuente/"


def nombre_columna(original):
    """Preparar nombres de columnas para guardarlos en Delta."""

    if original == "Store #":
        return "store_number"

    if original == "_rescued_data":
        return original

    return re.sub(
        r"[^a-z0-9]+",
        "_",
        original.lower()
    ).strip("_")


@dp.table(
    name="bronze_pos_raw",
    comment="Líneas del POS con valores originales y archivo de origen."
)
@dp.expect(
    "archivo_identificado",
    "source_file IS NOT NULL"
)
def bronze_pos_raw():

    datos = (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("cloudFiles.inferColumnTypes", "false")
        .option("rescuedDataColumn", "_rescued_data")
        .option("mode", "FAILFAST")
        .option("pathGlobFilter", "*.csv")
        .load(RUTA_FUENTE)
    )

    nombres = [
        nombre_columna(columna)
        for columna in datos.columns
    ]

    if len(nombres) != len(set(nombres)):
        raise ValueError(
            "Dos columnas producen el mismo nombre. Revisar encabezados."
        )

    columnas = [
        F.col(f"`{original}`").alias(nuevo)
        for original, nuevo in zip(datos.columns, nombres)
    ]

    return datos.select(
        *columnas,
        F.col("_metadata.file_path").alias("source_file"),
        F.col("_metadata.file_modification_time").alias(
            "source_modified_at"
        ),
        F.current_timestamp().alias("ingested_at")
    )