{{ config(
  materialized='view',
  tags=['intermediate', 'copilot', 'cost_and_usage']
) }}

WITH billing AS (
  SELECT * FROM {{ ref('stg_copilot_billing') }}
),

usage AS (
  SELECT * FROM {{ ref('stg_copilot_usage') }}
),

-- Seat charges: recurring monthly per-user
seats AS (
  SELECT
    monthly_cost                          AS BilledCost,

    'myorg'                               AS BillingAccountId,
    'My Organization'                     AS BillingAccountName,
    CAST(NULL AS VARCHAR)                 AS BillingAccountType,

    'USD'                                 AS BillingCurrency,
    seat_created_at                       AS BillingPeriodStart,
    DATE_TRUNC('month', seat_created_at) + INTERVAL '1 month' - INTERVAL '1 day'
                                          AS BillingPeriodEnd,

    'Usage'                               AS ChargeCategory,
    'Regular'                             AS ChargeClass,
    'GitHub Copilot ' || plan_type || ' - ' || user_name
                                          AS ChargeDescription,
    'Recurring'                           AS ChargeFrequency,

    seat_created_at                       AS ChargePeriodStart,
    seat_created_at + INTERVAL '1 month' - INTERVAL '1 day'
                                          AS ChargePeriodEnd,

    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountCategory,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountId,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountName,
    CAST(NULL AS DOUBLE)                  AS CommitmentDiscountQuantity,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountStatus,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountType,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountUnit,

    1::DOUBLE                            AS ConsumedQuantity,
    'Seats'                               AS ConsumedUnit,

    monthly_cost                          AS ContractedCost,
    monthly_cost                          AS ContractedUnitPrice,

    monthly_cost                          AS EffectiveCost,
    monthly_cost                          AS ListCost,
    CAST(NULL AS DOUBLE)                  AS ListUnitPrice,

    CAST(NULL AS VARCHAR)                 AS PricingCategory,
    'USD'                                 AS PricingCurrency,
    1::DOUBLE                            AS PricingQuantity,
    'Seats'                               AS PricingUnit,

    'AI / LLM'                            AS ServiceCategory,
    'GitHub Copilot'                      AS ServiceName,
    plan_type                             AS ServiceSubcategory,
    CAST(NULL AS VARCHAR)                 AS SkuId,
    CAST(NULL AS VARCHAR)                 AS SkuMeter,
    CAST(NULL AS VARCHAR)                 AS SkuPriceDetails,
    CAST(NULL AS VARCHAR)                 AS SkuPriceId,

    user_name                             AS SubAccountId,
    user_name                             AS SubAccountName,
    'User'                                AS SubAccountType,

    CAST(NULL AS VARCHAR)                 AS AvailabilityZone,
    CAST(NULL AS VARCHAR)                 AS CapacityReservationId,
    CAST(NULL AS VARCHAR)                 AS CapacityReservationStatus,
    CAST(NULL AS VARCHAR)                 AS ResourceId,
    CAST(NULL AS VARCHAR)                 AS ResourceName,
    CAST(NULL AS VARCHAR)                 AS ResourceType,
    CAST(NULL AS VARCHAR)                 AS RegionId,
    CAST(NULL AS VARCHAR)                 AS RegionName,
    CAST(NULL AS VARCHAR)                 AS Tags,
    CAST(NULL AS VARCHAR)                 AS InvoiceId,

    'GitHub'                              AS InvoiceIssuerName,
    CAST(NULL AS VARCHAR)                 AS InvoiceDetailId,
    CAST(NULL AS VARCHAR)                 AS AllocatedResourceId,
    CAST(NULL AS VARCHAR)                 AS AllocatedResourceName,
    CAST(NULL AS VARCHAR)                 AS AllocatedMethodId,
    CAST(NULL AS VARCHAR)                 AS AllocatedMethodDetails,
    CAST(NULL AS VARCHAR)                 AS AllocatedTags,
    CAST(NULL AS VARCHAR)                 AS ContractApplied,
    CAST(NULL AS VARCHAR)                 AS CommitmentProgramEligibilityDetails,

    'GitHub'                              AS HostProviderName,
    'GitHub'                              AS ServiceProviderName,

    CURRENT_TIMESTAMP                     AS _loaded_at,
    'seat'                                AS _charge_type,
    plan_type                             AS _plan_type
  FROM billing
),

-- Usage charges: pay-per-request AI credits
credits AS (
  SELECT
    net_amount                            AS BilledCost,

    'myorg'                               AS BillingAccountId,
    'My Organization'                     AS BillingAccountName,
    CAST(NULL AS VARCHAR)                 AS BillingAccountType,

    'USD'                                 AS BillingCurrency,
    usage_date                            AS BillingPeriodStart,
    usage_date                            AS BillingPeriodEnd,

    'Usage'                               AS ChargeCategory,
    'Regular'                             AS ChargeClass,
    'GitHub Copilot AI Credits - ' || model
                                          AS ChargeDescription,
    'Usage-Based'                         AS ChargeFrequency,

    usage_date                            AS ChargePeriodStart,
    usage_date                            AS ChargePeriodEnd,

    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountCategory,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountId,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountName,
    CAST(NULL AS DOUBLE)                  AS CommitmentDiscountQuantity,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountStatus,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountType,
    CAST(NULL AS VARCHAR)                 AS CommitmentDiscountUnit,

    quantity::DOUBLE                      AS ConsumedQuantity,
    unit_type                             AS ConsumedUnit,

    net_amount                            AS ContractedCost,
    net_amount / NULLIF(quantity, 0)      AS ContractedUnitPrice,

    net_amount                            AS EffectiveCost,
    gross_amount                          AS ListCost,
    gross_amount / NULLIF(quantity, 0)    AS ListUnitPrice,

    CAST(NULL AS VARCHAR)                 AS PricingCategory,
    'USD'                                 AS PricingCurrency,
    quantity::DOUBLE                      AS PricingQuantity,
    unit_type                             AS PricingUnit,

    'AI / LLM'                            AS ServiceCategory,
    'GitHub Copilot'                      AS ServiceName,
    model                                 AS ServiceSubcategory,
    sku                                   AS SkuId,
    CAST(NULL AS VARCHAR)                 AS SkuMeter,
    CAST(NULL AS VARCHAR)                 AS SkuPriceDetails,
    CAST(NULL AS VARCHAR)                 AS SkuPriceId,

    user_name                             AS SubAccountId,
    user_name                             AS SubAccountName,
    'User'                                AS SubAccountType,

    CAST(NULL AS VARCHAR)                 AS AvailabilityZone,
    CAST(NULL AS VARCHAR)                 AS CapacityReservationId,
    CAST(NULL AS VARCHAR)                 AS CapacityReservationStatus,
    CAST(NULL AS VARCHAR)                 AS ResourceId,
    CAST(NULL AS VARCHAR)                 AS ResourceName,
    CAST(NULL AS VARCHAR)                 AS ResourceType,
    CAST(NULL AS VARCHAR)                 AS RegionId,
    CAST(NULL AS VARCHAR)                 AS RegionName,
    CAST(NULL AS VARCHAR)                 AS Tags,
    CAST(NULL AS VARCHAR)                 AS InvoiceId,

    'GitHub'                              AS InvoiceIssuerName,
    CAST(NULL AS VARCHAR)                 AS InvoiceDetailId,
    CAST(NULL AS VARCHAR)                 AS AllocatedResourceId,
    CAST(NULL AS VARCHAR)                 AS AllocatedResourceName,
    CAST(NULL AS VARCHAR)                 AS AllocatedMethodId,
    CAST(NULL AS VARCHAR)                 AS AllocatedMethodDetails,
    CAST(NULL AS VARCHAR)                 AS AllocatedTags,
    CAST(NULL AS VARCHAR)                 AS ContractApplied,
    CAST(NULL AS VARCHAR)                 AS CommitmentProgramEligibilityDetails,

    'GitHub'                              AS HostProviderName,
    'GitHub'                              AS ServiceProviderName,

    CURRENT_TIMESTAMP                     AS _loaded_at,
    'ai_credits'                          AS _charge_type,
    model                                 AS _model
  FROM usage
)

SELECT * FROM seats
UNION ALL
SELECT * FROM credits
