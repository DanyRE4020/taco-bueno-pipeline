from pyspark import pipelines as dp
from pyspark.sql import functions as F


@dp.table(
    name="bronze_pos_raw",
    comment="Registros inventados para probar la limpieza de Silver."
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
        .option("pathGlobFilter", "casos_silver_v1.csv")
        .load(
            "/Volumes/workspace/"
            "taco_bueno_pruebas/entradas/"
        )
    )

    return datos.select(
        "*",
        F.col("_metadata.file_path").alias("source_file"),
        F.current_timestamp().alias("ingested_at")
    )