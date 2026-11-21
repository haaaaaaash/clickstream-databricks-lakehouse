"""schemas.py: explicit Spark schemas for the 7 raw CSV files (Bronze landing)

Bronze is a faithful copy of the source, so the types match the CSVs as they are:
- IDs and counts that are always whole numbers -> LONG / INT
- events.product_id, qty, cart_size are stored as floats in the CSV (93.0) -> DOUBLE (EDA finding #5)
- dates and timestamps stay STRING (e.g. signup_date is M/D/YYYY, EDA finding #6); dbt parses them in src_*
- column names are kept as in the CSV header; renaming happens in dbt

Reference: https://spark.apache.org/docs/3.5.0/sql-ref-datatypes.html
"""

from pyspark.sql.types import (
    BooleanType,
    DoubleType,
    IntegerType,
    LongType,
    StringType,
    StructField,
    StructType,
)


def _schema(*fields: tuple) -> StructType:
    """Builds a StructType from (name, type) pairs; every column is nullable, like in the CSV."""
    return StructType([StructField(name, dtype, True) for name, dtype in fields])


SCHEMAS: dict[str, StructType] = {
    "customers": _schema(
        ("customer_id", LongType()),
        ("name", StringType()),
        ("email", StringType()),
        ("country", StringType()),
        ("age", IntegerType()),
        ("signup_date", StringType()),
        ("marketing_opt_in", BooleanType()),
    ),
    "events": _schema(
        ("event_id", LongType()),
        ("session_id", LongType()),
        ("timestamp", StringType()),
        ("event_type", StringType()),
        ("product_id", DoubleType()),
        ("qty", DoubleType()),
        ("cart_size", DoubleType()),
        ("payment", StringType()),
        ("discount_pct", DoubleType()),
        ("amount_usd", DoubleType()),
    ),
    "order_items": _schema(
        ("order_id", LongType()),
        ("product_id", LongType()),
        ("unit_price_usd", DoubleType()),
        ("quantity", IntegerType()),
        ("line_total_usd", DoubleType()),
    ),
    "orders": _schema(
        ("order_id", LongType()),
        ("customer_id", LongType()),
        ("order_time", StringType()),
        ("payment_method", StringType()),
        ("discount_pct", IntegerType()),
        ("subtotal_usd", DoubleType()),
        ("total_usd", DoubleType()),
        ("country", StringType()),
        ("device", StringType()),
        ("source", StringType()),
    ),
    "products": _schema(
        ("product_id", LongType()),
        ("category", StringType()),
        ("name", StringType()),
        ("price_usd", DoubleType()),
        ("cost_usd", DoubleType()),
        ("margin_usd", DoubleType()),
    ),
    "reviews": _schema(
        ("review_id", LongType()),
        ("order_id", LongType()),
        ("product_id", LongType()),
        ("rating", IntegerType()),
        ("review_text", StringType()),
        ("review_time", StringType()),
    ),
    "sessions": _schema(
        ("session_id", LongType()),
        ("customer_id", LongType()),
        ("start_time", StringType()),
        ("device", StringType()),
        ("source", StringType()),
        ("country", StringType()),
    ),
}
