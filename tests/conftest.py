"""conftest.py: shared pytest fixtures

A small local SparkSession (no cluster, no Databricks) for the ingestion unit tests.
Needs Java 17 and pyspark from requirements.txt.
"""

import pytest
from pyspark.sql import SparkSession


@pytest.fixture(scope="session")
def spark():
    session = (
        SparkSession.builder.master("local[1]")
        .appName("clickstream-tests")
        .config("spark.sql.shuffle.partitions", "1")
        .config("spark.ui.enabled", "false")
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )
    yield session
    session.stop()


@pytest.fixture
def write_csv(tmp_path):
    """Writes a small CSV file into a temp folder and returns its path."""

    def _write(name: str, content: str) -> str:
        path = tmp_path / f"{name}.csv"
        path.write_text(content.strip() + "\n")
        return str(path)

    return _write
