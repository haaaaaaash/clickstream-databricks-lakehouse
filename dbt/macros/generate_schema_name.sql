-- generate_schema_name.sql: use the custom schema name as-is (silver, gold, test_failures)
-- instead of dbt's default <target_schema>_<custom_schema> (e.g. silver_gold).
-- Lower case: Unity Catalog stores schema names in lower case.
-- Reference: https://docs.getdbt.com/docs/build/custom-schemas
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | lower }}
    {%- endif -%}
{%- endmacro %}
