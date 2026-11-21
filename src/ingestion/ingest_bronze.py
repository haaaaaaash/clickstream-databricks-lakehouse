"""ingest_bronze.py: loads the raw CSVs from the Unity Catalog volume into Bronze Delta tables

Run on Databricks by the job in resources/ingest_bronze_job.yml:
    ingest_bronze.py --catalog clickstream --src-dir <folder of this file>

For each of the 7 tables:
    1. read the CSV with an explicit schema (schemas.py); the header must match it, bad rows fail the job
    2. add metadata columns: _ingested_at (load time), _source_file (file path in the volume)
    3. write a Delta table <catalog>.bronze.<table> (full overwrite, so re-runs are idempotent)
No type fixes, no renames, no dedup: Bronze is a faithful copy of the source (cleaning happens in dbt).

References:
- CSV options: https://spark.apache.org/docs/3.5.0/sql-data-sources-csv.html
- File metadata column: https://learn.microsoft.com/azure/databricks/ingestion/file-metadata-column
- Delta tables: https://learn.microsoft.com/azure/databricks/delta/
"""

import argparse
import os
import sys

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType


def read_csv(spark: SparkSession, path: str, schema: StructType) -> DataFrame:
    """Reads one CSV with an explicit schema.

    enforceSchema=False: the CSV header must match the schema's column names (catches renamed columns).
    mode=FAILFAST: a value that does not fit its type fails the read instead of silently becoming null.
    multiLine + escape: review texts may contain commas, quotes or line breaks.
    """
    return (
        spark.read.format("csv")
        .schema(schema)
        .option("header", True)
        .option("enforceSchema", False)
        .option("mode", "FAILFAST")
        .option("multiLine", True)
        .option("escape", '"')
        .load(path)
    )


def add_metadata(df: DataFrame) -> DataFrame:
    """Adds lineage columns: when the row was loaded and from which file."""
    return df.withColumn("_ingested_at", F.current_timestamp()).withColumn("_source_file", F.col("_metadata.file_path"))


def ingest_table(spark: SparkSession, table: str, schema: StructType, volume_path: str, catalog: str) -> int:
    """CSV -> Bronze Delta table. Returns the number of rows written."""
    df = add_metadata(read_csv(spark, f"{volume_path}/{table}.csv", schema))
    target = f"{catalog}.bronze.{table}"
    (df.write.format("delta").mode("overwrite").option("overwriteSchema", True).saveAsTable(target))
    return spark.table(target).count()


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Load the raw CSVs into Bronze Delta tables")
    parser.add_argument("--catalog", required=True, help="Unity Catalog catalog, e.g. clickstream")
    parser.add_argument("--volume", default="bronze/raw_files", help="schema/volume with the CSV files")
    parser.add_argument(
        "--src-dir",
        default=None,
        help="folder with schemas.py; needed on serverless, where __file__ is not defined",
    )
    args = parser.parse_args(argv)

    # Make schemas.py importable: explicit folder from the job, else this file's folder (local runs)
    src_dir = args.src_dir or os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, src_dir)
    from schemas import SCHEMAS

    spark = SparkSession.builder.getOrCreate()
    volume_path = f"/Volumes/{args.catalog}/{args.volume}"

    print(f"Loading {len(SCHEMAS)} tables from {volume_path} into {args.catalog}.bronze")
    for table, schema in SCHEMAS.items():
        rows = ingest_table(spark, table, schema, volume_path, args.catalog)
        print(f"  {table:<12} {rows:>9,} rows")
    print("Done.")


if __name__ == "__main__":
    main()
