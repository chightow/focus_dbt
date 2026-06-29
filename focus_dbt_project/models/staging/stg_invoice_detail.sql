{{ config(
  materialized='view',
  tags=['staging', 'invoice_detail']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('ind_csv_path', 'data/invoice_detail.csv')) }}
  {% if var('ind_parquet_path', none) %}
  UNION ALL
  SELECT *
  FROM {{ focus_read_parquet(var('ind_parquet_path')) }}
  {% endif %}
)

SELECT
  *,
  CURRENT_TIMESTAMP AS _loaded_at,
  '{{ var('focus_version', '1.4') }}' AS _focus_version
FROM source
