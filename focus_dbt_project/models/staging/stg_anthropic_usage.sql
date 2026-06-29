{{ config(
  materialized='view',
  tags=['staging', 'anthropic', 'usage']
) }}

WITH raw AS (
  SELECT *
  FROM {{ focus_read_json(var('anthropic_usage_path', 'data/anthropic_usage.json')) }}
),

unwound AS (
  SELECT
    b.starting_at::TIMESTAMP AS bucket_start,
    b.ending_at::TIMESTAMP   AS bucket_end,
    r.uncached_input_tokens::BIGINT   AS uncached_input_tokens,
    r.cache_read_input_tokens::BIGINT  AS cache_read_input_tokens,
    r.output_tokens::BIGINT            AS output_tokens,
    r.cache_creation.ephemeral_1h_input_tokens::BIGINT   AS cache_creation_1h_tokens,
    r.cache_creation.ephemeral_5m_input_tokens::BIGINT   AS cache_creation_5m_tokens,
    r.server_tool_use.web_search_requests::BIGINT         AS web_search_requests,
    r.model::VARCHAR          AS model,
    r.api_key_id::VARCHAR     AS api_key_id,
    r.workspace_id::VARCHAR   AS workspace_id,
    r.account_id::VARCHAR     AS account_id,
    r.service_account_id::VARCHAR AS service_account_id,
    r.service_tier::VARCHAR   AS service_tier,
    r.context_window::VARCHAR AS context_window,
    r.inference_geo::VARCHAR  AS inference_geo,
    CURRENT_TIMESTAMP         AS _loaded_at
  FROM raw
  CROSS JOIN UNNEST(data) AS t(b)
  CROSS JOIN UNNEST(b.results) AS s(r)
)

SELECT * FROM unwound
