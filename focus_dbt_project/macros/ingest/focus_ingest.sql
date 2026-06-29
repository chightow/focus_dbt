{% macro focus_read_csv(csv_path, header=true, delimiter=',', quote='"') %}
  {{ return(adapter.dispatch('focus_read_csv', 'focus_validator_dbt')(csv_path, header, delimiter, quote)) }}
{% endmacro %}

{% macro default__focus_read_csv(csv_path, header=true, delimiter=',', quote='"') %}
  read_csv_auto(
    '{{ csv_path }}',
    header={{ header | lower }},
    delim='{{ delimiter }}',
    quote='{{ quote }}',
    sample_size=100000,
    all_varchar=true
  )
{% endmacro %}

{% macro focus_read_parquet(parquet_path, hive_partitioning=true) %}
  {{ return(adapter.dispatch('focus_read_parquet', 'focus_validator_dbt')(parquet_path, hive_partitioning)) }}
{% endmacro %}

{% macro default__focus_read_parquet(parquet_path, hive_partitioning=true) %}
  read_parquet(
    '{{ parquet_path }}',
    hive_partitioning={{ hive_partitioning | lower }},
    union_by_name=true
  )
{% endmacro %}

{% macro focus_read_json(json_path, json_format='auto') %}
  {{ return(adapter.dispatch('focus_read_json', 'focus_validator_dbt')(json_path, json_format)) }}
{% endmacro %}

{% macro default__focus_read_json(json_path, json_format='auto') %}
  read_json_auto(
    '{{ json_path }}',
    format='{{ json_format }}',
    sample_size=100000
  )
{% endmacro %}

{% macro focus_glob(pattern) %}
  {{ return(adapter.dispatch('focus_glob', 'focus_validator_dbt')(pattern)) }}
{% endmacro %}

{% macro default__focus_glob(pattern) %}
  glob('{{ pattern }}')
{% endmacro %}

{% macro focus_list_tables(schema='main', database='focus') %}
  {{ return(adapter.dispatch('focus_list_tables', 'focus_validator_dbt')(schema, database)) }}
{% endmacro %}

{% macro default__focus_list_tables(schema='main', database='focus') %}
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = '{{ schema }}'
    AND table_catalog = '{{ database }}'
{% endmacro %}

{% macro focus_describe_table(table_name, schema='main', database='focus') %}
  {{ return(adapter.dispatch('focus_describe_table', 'focus_validator_dbt')(table_name, schema, database)) }}
{% endmacro %}

{% macro default__focus_describe_table(table_name, schema='main', database='focus') %}
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_name = '{{ table_name }}'
    AND table_schema = '{{ schema }}'
    AND table_catalog = '{{ database }}'
{% endmacro %}

{% macro focus_attach_sqlite(db_path, alias='ext_source') %}
  {{ return(adapter.dispatch('focus_attach_sqlite', 'focus_validator_dbt')(db_path, alias)) }}
{% endmacro %}

{% macro default__focus_attach_sqlite(db_path, alias='ext_source') %}
  ATTACH '{{ db_path }}' AS {{ alias }} (TYPE sqlite)
{% endmacro %}

{% macro focus_attach_postgres(conn_string, alias='ext_source') %}
  {{ return(adapter.dispatch('focus_attach_postgres', 'focus_validator_dbt')(conn_string, alias)) }}
{% endmacro %}

{% macro default__focus_attach_postgres(conn_string, alias='ext_source') %}
  ATTACH '{{ conn_string }}' AS {{ alias }} (TYPE postgres)
{% endmacro %}

{% macro focus_attach_mysql(conn_string, alias='ext_source') %}
  {{ return(adapter.dispatch('focus_attach_mysql', 'focus_validator_dbt')(conn_string, alias)) }}
{% endmacro %}

{% macro default__focus_attach_mysql(conn_string, alias='ext_source') %}
  ATTACH '{{ conn_string }}' AS {{ alias }} (TYPE mysql)
{% endmacro %}
