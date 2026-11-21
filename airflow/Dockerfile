FROM astrocrpublic.azurecr.io/runtime:3.3-9

# dbt in a separate virtualenv (used by Cosmos through ExecutionConfig.dbt_executable_path)
RUN python -m venv dbt_venv && \
    . dbt_venv/bin/activate && \
    pip install --no-cache-dir "dbt-core>=1.10,<2.0" "dbt-databricks>=1.10,<2.0" && \
    deactivate
