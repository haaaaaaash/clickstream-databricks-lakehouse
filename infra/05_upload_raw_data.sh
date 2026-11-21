#!/bin/bash
# 05_upload_raw_data.sh: uploads the 7 Kaggle CSVs from data/raw/ to the Unity Catalog volume
# Usage (from the repo root): bash infra/05_upload_raw_data.sh
# Prerequisite: 03_setup_unity_catalog.sql has run (volume <catalog>.bronze.raw_files exists)
# Target: /Volumes/<catalog>/bronze/raw_files/  (read by the PySpark ingestion job)
# Safe to re-run: files are overwritten.
set -euo pipefail

# 0. Load .env
if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run from the repo root (see .env.example)."
  exit 1
fi
set -a; source .env; set +a
: "${DATABRICKS_ADMIN_PROFILE:?missing in .env}" "${DATABRICKS_CATALOG:?missing in .env}"
P="$DATABRICKS_ADMIN_PROFILE"
VOLUME="dbfs:/Volumes/$DATABRICKS_CATALOG/bronze/raw_files"
FILES="customers events order_items orders products reviews sessions"

echo "1. Checking the local files in data/raw/..."
for f in $FILES; do
  if [ ! -f "data/raw/$f.csv" ]; then
    echo "ERROR: data/raw/$f.csv not found. Download the 7 CSVs from Kaggle first (see data/raw/README.md)."
    exit 1
  fi
done
echo "   all 7 files found"

echo "2. Uploading to $VOLUME..."
for f in $FILES; do
  databricks fs cp "data/raw/$f.csv" "$VOLUME/$f.csv" --overwrite -p "$P" > /dev/null
  echo "   $f.csv ($(du -h "data/raw/$f.csv" | cut -f1))"
done

echo "3. Files in the volume:"
databricks fs ls "$VOLUME" -l -p "$P"

echo
echo "Done. Next: the PySpark job loads these files into Bronze Delta tables."
