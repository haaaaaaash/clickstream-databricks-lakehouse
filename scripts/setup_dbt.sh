#!/bin/bash
# setup_dbt.sh: prepares the dbt project in dbt/ and tests the connection as the service principal
# Usage (from the repo root): bash scripts/setup_dbt.sh
# Prerequisite: the dbt config files are in dbt/ (dbt_project.yml, profiles.yml, packages.yml,
#   macros/generate_schema_name.sql) and .env has the workspace + service principal values (Ch. 4)
# Safe to re-run.
set -euo pipefail

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run from the repo root (see .env.example)."
  exit 1
fi
if [ ! -f dbt/dbt_project.yml ]; then
  echo "ERROR: dbt/dbt_project.yml not found. Copy the dbt config files into dbt/ first."
  exit 1
fi

echo "1. Creating dbt folders..."
mkdir -p dbt/models/staging dbt/models/silver dbt/models/gold dbt/tests dbt/seeds dbt/analyses

echo "2. Checking the dbt paths in .env and .env.example..."
for f in .env .env.example; do
  [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ] && echo >> "$f"   # make sure the file ends with a newline
  grep -q "^DBT_PROJECT_DIR="  "$f" || echo "DBT_PROJECT_DIR=dbt"  >> "$f"
  grep -q "^DBT_PROFILES_DIR=" "$f" || echo "DBT_PROFILES_DIR=dbt" >> "$f"
done

echo "3. Ignoring dbt output folders in Git..."
for p in "dbt/target/" "dbt/dbt_packages/" "dbt/logs/" "logs/" "dbt/.user.yml"; do
  grep -qxF "$p" .gitignore || echo "$p" >> .gitignore
done

echo "4. Installing dbt packages + testing the connection (as the service principal)..."
# DBT_PROJECT_DIR=dbt and DBT_PROFILES_DIR=dbt (from .env): dbt is run from the repo root
set -a; source .env; set +a
dbt --version
dbt deps
dbt debug

echo
echo "Done. Run dbt from the repo root with .env loaded (direnv, or: set -a; source .env; set +a)"
