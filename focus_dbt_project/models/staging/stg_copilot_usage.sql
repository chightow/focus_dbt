{{ config(
  materialized='view',
  tags=['staging', 'copilot', 'usage']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('copilot_usage_path', 'data/copilot_usage.csv')) }}
)

SELECT
  date::DATE                        AS usage_date,
  product::VARCHAR                  AS product,
  sku::VARCHAR                      AS sku,
  model::VARCHAR                    AS model,
  unit_type::VARCHAR                AS unit_type,
  quantity::BIGINT                  AS quantity,
  gross_amount::DOUBLE              AS gross_amount,
  discount_amount::DOUBLE           AS discount_amount,
  net_amount::DOUBLE                AS net_amount,
  organization::VARCHAR             AS organization,
  user::VARCHAR                     AS user_name,
  team::VARCHAR                     AS team,
  CURRENT_TIMESTAMP                 AS _loaded_at
FROM source
