{{ config(
  materialized='view',
  tags=['staging', 'anthropic', 'cost']
) }}

WITH raw AS (
  SELECT *
  FROM {{ focus_read_json(var('anthropic_cost_path', 'data/anthropic_cost.json')) }}
),

unwound AS (
  SELECT
    b.starting_at::TIMESTAMP  AS bucket_start,
    b.ending_at::TIMESTAMP    AS bucket_end,
    r.amount::VARCHAR         AS amount_cents,
    r.amount::DOUBLE / 100.0  AS amount_usd,
    r.currency::VARCHAR       AS currency,
    r.cost_type::VARCHAR      AS cost_type,
    r.description::VARCHAR    AS description,
    r.model::VARCHAR          AS model,
    r.token_type::VARCHAR     AS token_type,
    r.workspace_id::VARCHAR   AS workspace_id,
    r.service_tier::VARCHAR   AS service_tier,
    r.context_window::VARCHAR AS context_window,
    r.inference_geo::VARCHAR  AS inference_geo,
    CURRENT_TIMESTAMP         AS _loaded_at
  FROM raw
  CROSS JOIN UNNEST(data) AS t(b)
  CROSS JOIN UNNEST(b.results) AS s(r)
)

SELECT * FROM unwound
