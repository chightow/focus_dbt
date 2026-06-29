{{ config(
  materialized='view',
  tags=['intermediate', 'anthropic', 'cost_and_usage']
) }}

WITH usage AS (
  SELECT * FROM {{ ref('stg_anthropic_usage') }}
),

cost AS (
  SELECT * FROM {{ ref('stg_anthropic_cost') }}
),

-- Aggregate usage to (bucket, model, workspace) level
usage_agg AS (
  SELECT
    bucket_start,
    bucket_end,
    model,
    workspace_id,
    SUM(uncached_input_tokens)        AS uncached_input_tokens,
    SUM(cache_read_input_tokens)       AS cache_read_input_tokens,
    SUM(cache_creation_1h_tokens)      AS cache_creation_1h_tokens,
    SUM(cache_creation_5m_tokens)      AS cache_creation_5m_tokens,
    SUM(output_tokens)                 AS output_tokens,
    SUM(web_search_requests)           AS web_search_requests,
    LIST(DISTINCT service_tier) AS service_tiers,
    LIST(DISTINCT api_key_id)   AS api_key_ids
  FROM usage
  GROUP BY bucket_start, bucket_end, model, workspace_id
),

-- Aggregate cost to (bucket, model, workspace, token_type) level
cost_agg AS (
  SELECT
    bucket_start,
    bucket_end,
    model,
    workspace_id,
    token_type,
    cost_type,
    SUM(amount_usd) AS amount_usd
  FROM cost
  WHERE amount_usd IS NOT NULL
  GROUP BY bucket_start, bucket_end, model, workspace_id, token_type, cost_type
),

-- UNPIVOT the 5 token types + web_search into separate rows
fanned AS (
  SELECT bucket_start, bucket_end, model, workspace_id,
         'uncached_input_tokens' AS token_slot,
         uncached_input_tokens AS quantity,
         'Tokens' AS unit,
         'Uncached Input Tokens' AS label,
         'uncached_input_tokens' AS cost_key,
         service_tiers, api_key_ids
  FROM usage_agg WHERE uncached_input_tokens > 0
  UNION ALL
  SELECT bucket_start, bucket_end, model, workspace_id,
         'cache_read_input_tokens' AS token_slot,
         cache_read_input_tokens AS quantity,
         'Tokens' AS unit,
         'Cache Read Tokens' AS label,
         'cache_read_input_tokens' AS cost_key,
         service_tiers, api_key_ids
  FROM usage_agg WHERE cache_read_input_tokens > 0
  UNION ALL
  SELECT bucket_start, bucket_end, model, workspace_id,
         'cache_creation_1h_tokens' AS token_slot,
         cache_creation_1h_tokens AS quantity,
         'Tokens' AS unit,
         'Cache Create 1h Tokens' AS label,
         'cache_creation.ephemeral_1h_input_tokens' AS cost_key,
         service_tiers, api_key_ids
  FROM usage_agg WHERE cache_creation_1h_tokens > 0
  UNION ALL
  SELECT bucket_start, bucket_end, model, workspace_id,
         'cache_creation_5m_tokens' AS token_slot,
         cache_creation_5m_tokens AS quantity,
         'Tokens' AS unit,
         'Cache Create 5m Tokens' AS label,
         'cache_creation.ephemeral_5m_input_tokens' AS cost_key,
         service_tiers, api_key_ids
  FROM usage_agg WHERE cache_creation_5m_tokens > 0
  UNION ALL
  SELECT bucket_start, bucket_end, model, workspace_id,
         'output_tokens' AS token_slot,
         output_tokens AS quantity,
         'Tokens' AS unit,
         'Output Tokens' AS label,
         'output_tokens' AS cost_key,
         service_tiers, api_key_ids
  FROM usage_agg WHERE output_tokens > 0
  UNION ALL
  SELECT bucket_start, bucket_end, model, workspace_id,
         'web_search_requests' AS token_slot,
         web_search_requests AS quantity,
         'Requests' AS unit,
         'Web Search Requests' AS label,
         NULL AS cost_key,
         service_tiers, api_key_ids
  FROM usage_agg WHERE web_search_requests > 0
)

SELECT
  -- Cost: match cost_agg on (bucket, model, workspace, token_type)
  COALESCE(c.amount_usd, 0.0)              AS BilledCost,

  'anthropic_org'                           AS BillingAccountId,
  'Anthropic Organization'                  AS BillingAccountName,
  CAST(NULL AS VARCHAR)                     AS BillingAccountType,

  'USD'                                     AS BillingCurrency,
  f.bucket_start                            AS BillingPeriodStart,
  f.bucket_end                              AS BillingPeriodEnd,

  CASE
    WHEN f.token_slot = 'web_search_requests' THEN 'Fee'
    ELSE 'Usage'
  END                                       AS ChargeCategory,

  'Regular'                                 AS ChargeClass,
  f.model || ' - ' || f.label               AS ChargeDescription,
  'Usage-Based'                             AS ChargeFrequency,

  f.bucket_start                            AS ChargePeriodStart,
  f.bucket_end                              AS ChargePeriodEnd,

  CAST(NULL AS VARCHAR)                     AS CommitmentDiscountCategory,
  CAST(NULL AS VARCHAR)                     AS CommitmentDiscountId,
  CAST(NULL AS VARCHAR)                     AS CommitmentDiscountName,
  CAST(NULL AS DOUBLE)                      AS CommitmentDiscountQuantity,
  CAST(NULL AS VARCHAR)                     AS CommitmentDiscountStatus,
  CAST(NULL AS VARCHAR)                     AS CommitmentDiscountType,
  CAST(NULL AS VARCHAR)                     AS CommitmentDiscountUnit,

  f.quantity::DOUBLE                        AS ConsumedQuantity,
  f.unit                                    AS ConsumedUnit,

  COALESCE(c.amount_usd, 0.0)              AS ContractedCost,
  CASE
    WHEN f.unit = 'Tokens' AND f.quantity > 0
      THEN COALESCE(c.amount_usd, 0.0) / f.quantity
    ELSE CAST(NULL AS DOUBLE)
  END                                       AS ContractedUnitPrice,

  COALESCE(c.amount_usd, 0.0)              AS EffectiveCost,
  COALESCE(c.amount_usd, 0.0)              AS ListCost,
  CAST(NULL AS DOUBLE)                      AS ListUnitPrice,

  CAST(NULL AS VARCHAR)                     AS PricingCategory,
  'USD'                                     AS PricingCurrency,

  f.quantity::DOUBLE                        AS PricingQuantity,
  f.unit                                    AS PricingUnit,

  'AI / LLM'                                AS ServiceCategory,
  f.model                                   AS ServiceName,
  CAST(NULL AS VARCHAR)                     AS ServiceSubcategory,
  CAST(NULL AS VARCHAR)                     AS SkuId,
  CAST(NULL AS VARCHAR)                     AS SkuMeter,
  CAST(NULL AS VARCHAR)                     AS SkuPriceDetails,
  CAST(NULL AS VARCHAR)                     AS SkuPriceId,

  f.workspace_id                            AS SubAccountId,
  CAST(NULL AS VARCHAR)                     AS SubAccountName,
  'Workspace'                               AS SubAccountType,

  CAST(NULL AS VARCHAR)                     AS AvailabilityZone,
  CAST(NULL AS VARCHAR)                     AS CapacityReservationId,
  CAST(NULL AS VARCHAR)                     AS CapacityReservationStatus,
  CAST(NULL AS VARCHAR)                     AS ResourceId,
  CAST(NULL AS VARCHAR)                     AS ResourceName,
  CAST(NULL AS VARCHAR)                     AS ResourceType,
  CAST(NULL AS VARCHAR)                     AS RegionId,
  CAST(NULL AS VARCHAR)                     AS RegionName,
  CAST(NULL AS VARCHAR)                     AS Tags,
  CAST(NULL AS VARCHAR)                     AS InvoiceId,

  'Anthropic'                               AS InvoiceIssuerName,
  CAST(NULL AS VARCHAR)                     AS InvoiceDetailId,
  CAST(NULL AS VARCHAR)                     AS AllocatedResourceId,
  CAST(NULL AS VARCHAR)                     AS AllocatedResourceName,
  CAST(NULL AS VARCHAR)                     AS AllocatedMethodId,
  CAST(NULL AS VARCHAR)                     AS AllocatedMethodDetails,
  CAST(NULL AS VARCHAR)                     AS AllocatedTags,
  CAST(NULL AS VARCHAR)                     AS ContractApplied,
  CAST(NULL AS VARCHAR)                     AS CommitmentProgramEligibilityDetails,

  'Anthropic'                               AS HostProviderName,
  'Anthropic'                               AS ServiceProviderName,

  -- metadata
  CURRENT_TIMESTAMP                         AS _loaded_at,
  f.token_slot                              AS _token_type,
  f.label                                   AS _token_label

FROM fanned f
LEFT JOIN cost_agg c
  ON  f.bucket_start    = c.bucket_start
  AND f.model           = c.model
  AND (f.workspace_id   IS NOT DISTINCT FROM c.workspace_id)
  AND (
    (f.cost_key IS NOT NULL AND f.cost_key = c.token_type)
    OR (f.cost_key IS NULL AND c.cost_type = 'web_search')
  )
