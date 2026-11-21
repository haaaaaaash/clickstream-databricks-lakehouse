#!/bin/bash
# setup_repo.sh: creates the empty project skeleton for clickstream-databricks-lakehouse
# Usage (from the repo root, after cloning): bash setup_repo.sh
# Safe to re-run.
set -e

echo "1. Creating folders..."
# dbt/ is added later by scripts/setup_dbt.sh, airflow/ by 'astro dev init' (needs an empty folder)
FOLDERS="infra scripts src/ingestion resources tests data/raw notebooks docs/images docs/diagrams .github/workflows"
for d in $FOLDERS; do
  mkdir -p "$d"
  touch "$d/.gitkeep"   # Git does not track empty folders
done

echo "2. Adding project-specific rules to GitHub's Python .gitignore..."
if ! grep -q "Project-specific" .gitignore 2>/dev/null; then
cat >> .gitignore << 'EOF'

# ---- Project-specific ----
# Secrets (never commit)
.env
.envrc
*.pem

# Raw data (too large for Git, Kaggle license)
data/raw/*.csv

# dbt generated files
target/
dbt_packages/
logs/
.user.yml

# Databricks Asset Bundle local state
.databricks/

# Local PySpark test artifacts
spark-warehouse/
metastore_db/
derby.log

# IDE
.vscode/

# Windows download metadata (WSL)
*Zone.Identifier
EOF
fi

echo "3. Creating .gitattributes (Linux line endings for scripts)..."
if [ ! -f .gitattributes ]; then
cat > .gitattributes << 'EOF'
# Shell scripts and SQL must use Linux line endings (LF), even when edited on Windows
*.sh  text eol=lf
*.sql text eol=lf
*.py  text eol=lf
*.yml text eol=lf
EOF
fi

echo "Done."