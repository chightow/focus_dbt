{{ config(
  materialized='view',
  tags=['intermediate', 'aws', 'cost_and_usage']
) }}

WITH source AS (
  SELECT * FROM {{ ref('stg_aws_cur') }}
)

SELECT

  COALESCE(source.NetUnblendedCost, source.UnblendedCost) AS BilledCost,

  source.UsageAccountId                       AS BillingAccountId,
  source.UsageAccountId                       AS BillingAccountName,
  CAST(NULL AS VARCHAR)                       AS BillingAccountType,

  source.CurrencyCode                         AS BillingCurrency,
  source.BillingPeriodStartDate               AS BillingPeriodStart,
  source.BillingPeriodEndDate                 AS BillingPeriodEnd,

  CASE
    WHEN source.LineItemType = 'Usage' THEN 'Usage'
    WHEN source.LineItemType = 'Fee' THEN 'Fee'
    WHEN source.LineItemType = 'DiscountedUsage' THEN 'Usage'
    WHEN source.LineItemType = 'Credit' THEN 'Adjustment'
    ELSE 'Usage'
  END                                         AS ChargeCategory,

  'Regular'                                   AS ChargeClass,
  source.LineItemDescription                  AS ChargeDescription,
  'Usage-Based'                               AS ChargeFrequency,

  source.UsageStartDate                       AS ChargePeriodStart,
  source.UsageEndDate                         AS ChargePeriodEnd,

  CAST(NULL AS VARCHAR)                       AS CommitmentDiscountCategory,
  CAST(NULL AS VARCHAR)                       AS CommitmentDiscountId,
  CAST(NULL AS VARCHAR)                       AS CommitmentDiscountName,
  CAST(NULL AS DOUBLE)                        AS CommitmentDiscountQuantity,
  CAST(NULL AS VARCHAR)                       AS CommitmentDiscountStatus,
  CAST(NULL AS VARCHAR)                       AS CommitmentDiscountType,
  CAST(NULL AS VARCHAR)                       AS CommitmentDiscountUnit,

  source.UsageAmount                          AS ConsumedQuantity,
  source.PricingUnit                          AS ConsumedUnit,

  COALESCE(source.NetUnblendedCost, source.UnblendedCost) AS ContractedCost,
  NULLIF(COALESCE(source.NetUnblendedCost, source.UnblendedCost), 0)
    / NULLIF(source.UsageAmount, 0)           AS ContractedUnitPrice,

  COALESCE(source.NetUnblendedCost, source.UnblendedCost) AS EffectiveCost,
  source.UnblendedCost                        AS ListCost,
  NULLIF(source.UnblendedCost, 0)
    / NULLIF(source.UsageAmount, 0)           AS ListUnitPrice,

  CAST(NULL AS VARCHAR)                       AS PricingCategory,
  source.CurrencyCode                         AS PricingCurrency,
  source.UsageAmount                          AS PricingQuantity,
  source.PricingUnit                          AS PricingUnit,

  'AI / LLM'                                  AS ServiceCategory,
  source.ProductCode                          AS ServiceName,
  source.UsageType                            AS ServiceSubcategory,
  CAST(NULL AS VARCHAR)                       AS SkuId,
  CAST(NULL AS VARCHAR)                       AS SkuMeter,
  CAST(NULL AS VARCHAR)                       AS SkuPriceDetails,
  CAST(NULL AS VARCHAR)                       AS SkuPriceId,

  source.UsageAccountId                       AS SubAccountId,
  CAST(NULL AS VARCHAR)                       AS SubAccountName,
  'Account'                                   AS SubAccountType,

  CAST(NULL AS VARCHAR)                       AS AvailabilityZone,
  CAST(NULL AS VARCHAR)                       AS CapacityReservationId,
  CAST(NULL AS VARCHAR)                       AS CapacityReservationStatus,
  source.ResourceId,
  CAST(NULL AS VARCHAR)                       AS ResourceName,
  CAST(NULL AS VARCHAR)                       AS ResourceType,
  source.Region                               AS RegionId,
  CAST(NULL AS VARCHAR)                       AS RegionName,
  CAST(NULL AS VARCHAR)                       AS Tags,
  CAST(NULL AS VARCHAR)                       AS InvoiceId,

  'AWS'                                       AS InvoiceIssuerName,
  CAST(NULL AS VARCHAR)                       AS InvoiceDetailId,
  CAST(NULL AS VARCHAR)                       AS AllocatedResourceId,
  CAST(NULL AS VARCHAR)                       AS AllocatedResourceName,
  CAST(NULL AS VARCHAR)                       AS AllocatedMethodId,
  CAST(NULL AS VARCHAR)                       AS AllocatedMethodDetails,
  CAST(NULL AS VARCHAR)                       AS AllocatedTags,
  CAST(NULL AS VARCHAR)                       AS ContractApplied,
  CAST(NULL AS VARCHAR)                       AS CommitmentProgramEligibilityDetails,

  'AWS'                                       AS HostProviderName,
  'AWS'                                       AS ServiceProviderName,

  CURRENT_TIMESTAMP                           AS _loaded_at,
  source.LineItemType                         AS _line_item_type,
  source.Operation                            AS _operation,
  source.PricingTerm                          AS _pricing_term

FROM source
