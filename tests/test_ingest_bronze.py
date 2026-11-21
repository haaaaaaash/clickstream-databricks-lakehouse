"""Unit tests for the Bronze ingestion (local Spark, no Databricks needed)

Run (from the repo root): pytest
Each test covers one rule from the EDA findings: Bronze keeps the source as it is.
"""

import pytest
from pyspark.sql.types import DoubleType, StringType, TimestampType

from ingest_bronze import add_metadata, read_csv
from schemas import SCHEMAS

EVENTS_HEADER = "event_id,session_id,timestamp,event_type,product_id,qty,cart_size,payment,discount_pct,amount_usd"


def test_schemas_cover_all_seven_tables():
    assert set(SCHEMAS) == {"customers", "events", "order_items", "orders", "products", "reviews", "sessions"}


def test_float_ids_stay_double(spark, write_csv):
    """EDA #5: events.product_id is stored as 93.0; Bronze keeps it as DOUBLE, empty values become null."""
    path = write_csv(
        "events",
        f"""
{EVENTS_HEADER}
1,10,2024-01-01T10:00:00,page_view,93.0,,,,,
2,10,2024-01-01T10:05:00,checkout,,,3.0,,,
""",
    )
    df = read_csv(spark, path, SCHEMAS["events"])
    rows = df.orderBy("event_id").collect()

    assert df.schema["product_id"].dataType == DoubleType()
    assert rows[0]["product_id"] == 93.0
    assert rows[1]["product_id"] is None


def test_dates_stay_text(spark, write_csv):
    """EDA #6: signup_date is M/D/YYYY; Bronze keeps the original text, dbt parses it later."""
    path = write_csv(
        "customers",
        """
customer_id,name,email,country,age,signup_date,marketing_opt_in
1,Ann,ann@example.com,DE,34,9/4/2020,True
""",
    )
    row = read_csv(spark, path, SCHEMAS["customers"]).first()

    assert SCHEMAS["customers"]["signup_date"].dataType == StringType()
    assert row["signup_date"] == "9/4/2020"
    assert row["marketing_opt_in"] is True


def test_duplicate_rows_are_kept(spark, write_csv):
    """EDA #4: repeated order_items lines are valid; Bronze must not deduplicate."""
    path = write_csv(
        "order_items",
        """
order_id,product_id,unit_price_usd,quantity,line_total_usd
1,5,10.0,1,10.0
1,5,10.0,1,10.0
""",
    )
    assert read_csv(spark, path, SCHEMAS["order_items"]).count() == 2


def test_wrong_header_fails(spark, write_csv):
    """A renamed source column must stop the load instead of shifting data into the wrong column."""
    path = write_csv(
        "products",
        """
product_id,category,product_name,price_usd,cost_usd,margin_usd
1,Books,Novel,10.0,6.0,4.0
""",
    )
    with pytest.raises(Exception):  # noqa: B017 (Spark wraps the Java error in different types)
        read_csv(spark, path, SCHEMAS["products"]).collect()


def test_bad_value_fails(spark, write_csv):
    """FAILFAST: a value that does not fit its type fails instead of silently becoming null."""
    path = write_csv(
        "order_items",
        """
order_id,product_id,unit_price_usd,quantity,line_total_usd
1,5,10.0,one,10.0
""",
    )
    with pytest.raises(Exception):  # noqa: B017 (Spark wraps the Java error in different types)
        read_csv(spark, path, SCHEMAS["order_items"]).collect()


def test_quoted_text_with_commas(spark, write_csv):
    """Review texts can contain commas and quotes."""
    path = write_csv(
        "reviews",
        """
review_id,order_id,product_id,rating,review_text,review_time
1,7,5,4,"Good, but ""too"" small",2024-02-01T09:00:00
""",
    )
    row = read_csv(spark, path, SCHEMAS["reviews"]).first()
    assert row["review_text"] == 'Good, but "too" small'


def test_metadata_columns_added(spark, write_csv):
    """Lineage: every row gets the load time and the source file path."""
    path = write_csv(
        "sessions",
        """
session_id,customer_id,start_time,device,source,country
1,1,2024-01-01T10:00:00,mobile,direct,DE
""",
    )
    df = add_metadata(read_csv(spark, path, SCHEMAS["sessions"]))
    row = df.first()

    assert df.schema["_ingested_at"].dataType == TimestampType()
    assert row["_source_file"].endswith("sessions.csv")
    assert df.columns[: len(SCHEMAS["sessions"])] == SCHEMAS["sessions"].fieldNames()
