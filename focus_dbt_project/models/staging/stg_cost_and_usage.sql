{{ config(
  materialized='view',
  tags=['staging', 'cost_and_usage']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('cau_csv_path', 'data/cost_and_usage.csv')) }}
  {% if var('cau_parquet_path', none) %}
  UNION ALL
  SELECT *
  FROM {{ focus_read_parquet(var('cau_parquet_path')) }}
  {% endif %}
)

SELECT
  *,
  CURRENT_TIMESTAMP AS _loaded_at,
  '{{ var('focus_version', '1.4') }}' AS _focus_version
FROM source
