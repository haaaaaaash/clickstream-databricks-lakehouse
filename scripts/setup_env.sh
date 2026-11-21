#!/bin/bash
# setup_env.sh: creates the Python environment + installs the Azure and Databricks CLIs
# Usage (from the repo root): bash scripts/setup_env.sh
# Then activate: source .venv/bin/activate
# Safe to re-run: CLIs that are already installed are skipped.
set -e

echo "1. Checking uv and Java (Java 17 is needed for local PySpark tests)..."
uv --version
java -version 2>&1 | head -1 || { echo "ERROR: Java not found. Install Temurin 17 first."; exit 1; }

echo "2. Creating venv (Python 3.11, same as Databricks Runtime 15.4 LTS)..."
uv venv --python 3.11

echo "3. Installing packages from requirements.txt..."
uv pip install --python .venv -r requirements.txt

echo "4. Locking exact versions to requirements.lock..."
uv pip freeze --python .venv > requirements.lock

echo "5. Installing Azure CLI (system-wide, may ask for your sudo password)..."
if command -v az > /dev/null; then
  echo "   already installed -> skipped"
else
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

echo "6. Installing Databricks CLI (system-wide, may ask for your sudo password)..."
if command -v databricks > /dev/null; then
  echo "   already installed -> skipped"
else
  curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sudo sh
fi

echo "7. Verifying..."
.venv/bin/dbt --version
.venv/bin/python -c "import pyspark; print('pyspark', pyspark.__version__)"
az version --query '"azure-cli"' -o tsv
databricks --version

echo "Done. Activate with: source .venv/bin/activate"