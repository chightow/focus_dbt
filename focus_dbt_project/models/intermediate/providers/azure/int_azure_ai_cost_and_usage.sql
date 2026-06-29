{{ config(
  materialized='view',
  tags=['intermediate', 'azure', 'cost_and_usage']
) }}

WITH source AS (
  SELECT * FROM {{ ref('stg_azure_ai') }}
)

SELECT

  source.BilledCost,
  source.BillingAccountId,
  source.BillingAccountName,
  CAST(NULL AS VARCHAR)               AS BillingAccountType,
  source.BillingCurrency,
  source.BillingPeriodStart,
  source.BillingPeriodEnd,
  source.ChargeCategory,
  source.ChargeClass,
  source.ChargeDescription,
  source.ChargeFrequency,
  source.ChargePeriodStart,
  source.ChargePeriodEnd,

  CAST(NULL AS VARCHAR)               AS CommitmentDiscountCategory,
  CAST(NULL AS VARCHAR)               AS CommitmentDiscountId,
  CAST(NULL AS VARCHAR)               AS CommitmentDiscountName,
  CAST(NULL AS DOUBLE)                AS CommitmentDiscountQuantity,
  CAST(NULL AS VARCHAR)               AS CommitmentDiscountStatus,
  CAST(NULL AS VARCHAR)               AS CommitmentDiscountType,
  CAST(NULL AS VARCHAR)               AS CommitmentDiscountUnit,

  source.ConsumedQuantity,
  source.ConsumedUnit,
  source.ContractedCost,
  source.ContractedUnitPrice,
  source.EffectiveCost,
  source.ListCost,
  source.ListUnitPrice,

  CAST(NULL AS VARCHAR)               AS PricingCategory,
  source.BillingCurrency              AS PricingCurrency,
  source.ConsumedQuantity             AS PricingQuantity,
  source.ConsumedUnit                 AS PricingUnit,

  source.ServiceCategory,
  source.ServiceName,
  source.ServiceSubcategory,
  source.SkuId,
  CAST(NULL AS VARCHAR)               AS SkuMeter,
  CAST(NULL AS VARCHAR)               AS SkuPriceDetails,
  CAST(NULL AS VARCHAR)               AS SkuPriceId,

  source.SubAccountId,
  source.SubAccountName,
  source.SubAccountType,

  CAST(NULL AS VARCHAR)               AS AvailabilityZone,
  CAST(NULL AS VARCHAR)               AS CapacityReservationId,
  CAST(NULL AS VARCHAR)               AS CapacityReservationStatus,
  source.ResourceId,
  CAST(NULL AS VARCHAR)               AS ResourceName,
  source.ResourceType,
  source.RegionId,
  CAST(NULL AS VARCHAR)               AS RegionName,
  CAST(NULL AS VARCHAR)               AS Tags,
  CAST(NULL AS VARCHAR)               AS InvoiceId,

  'Microsoft'                         AS InvoiceIssuerName,
  CAST(NULL AS VARCHAR)               AS InvoiceDetailId,
  CAST(NULL AS VARCHAR)               AS AllocatedResourceId,
  CAST(NULL AS VARCHAR)               AS AllocatedResourceName,
  CAST(NULL AS VARCHAR)               AS AllocatedMethodId,
  CAST(NULL AS VARCHAR)               AS AllocatedMethodDetails,
  CAST(NULL AS VARCHAR)               AS AllocatedTags,
  CAST(NULL AS VARCHAR)               AS ContractApplied,
  CAST(NULL AS VARCHAR)               AS CommitmentProgramEligibilityDetails,

  'Microsoft'                         AS HostProviderName,
  'Microsoft'                         AS ServiceProviderName,

  CURRENT_TIMESTAMP                   AS _loaded_at,
  source.MeterCategory                AS _meter_category,
  source.MeterName                    AS _meter_name,
  source.ResourceGroup                AS _resource_group

FROM source
