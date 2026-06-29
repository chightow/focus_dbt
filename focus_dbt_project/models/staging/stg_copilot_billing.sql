{{ config(
  materialized='view',
  tags=['staging', 'copilot', 'billing']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('copilot_billing_path', 'data/copilot_billing.csv')) }}
)

SELECT
  user::VARCHAR                     AS user_name,
  organization::VARCHAR             AS organization,
  team::VARCHAR                     AS team,
  plan_type::VARCHAR                AS plan_type,
  seat_created_at::DATE             AS seat_created_at,
  last_activity_at::TIMESTAMP       AS last_activity_at,
  last_activity_editor::VARCHAR     AS last_activity_editor,
  monthly_cost::DOUBLE              AS monthly_cost,
  CURRENT_TIMESTAMP                 AS _loaded_at
FROM source
