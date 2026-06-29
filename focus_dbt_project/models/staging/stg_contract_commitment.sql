{{ config(
  materialized='view',
  tags=['staging', 'contract_commitment']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('cct_csv_path', 'data/contract_commitment.csv')) }}
  {% if var('cct_parquet_path', none) %}
  UNION ALL
  SELECT *
  FROM {{ focus_read_parquet(var('cct_parquet_path')) }}
  {% endif %}
)

SELECT
  *,
  CURRENT_TIMESTAMP AS _loaded_at,
  '{{ var('focus_version', '1.4') }}' AS _focus_version
FROM source
