{{ config(
  materialized='view',
  tags=['staging', 'billing_period']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('bip_csv_path', 'data/billing_period.csv')) }}
  {% if var('bip_parquet_path', none) %}
  UNION ALL
  SELECT *
  FROM {{ focus_read_parquet(var('bip_parquet_path')) }}
  {% endif %}
)

SELECT
  *,
  CURRENT_TIMESTAMP AS _loaded_at,
  '{{ var('focus_version', '1.4') }}' AS _focus_version
FROM source
