{{ config(
  materialized='view',
  tags=['staging', 'azure', 'ai']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('azure_ai_path', 'data/azure_ai.csv')) }}
)

SELECT
  BilledCost::DOUBLE              AS BilledCost,
  BillingAccountId::VARCHAR       AS BillingAccountId,
  BillingAccountName::VARCHAR     AS BillingAccountName,
  BillingCurrency::VARCHAR        AS BillingCurrency,
  BillingPeriodStart::DATE        AS BillingPeriodStart,
  BillingPeriodEnd::DATE          AS BillingPeriodEnd,
  ChargeCategory::VARCHAR         AS ChargeCategory,
  ChargeClass::VARCHAR            AS ChargeClass,
  ChargeDescription::VARCHAR      AS ChargeDescription,
  ChargeFrequency::VARCHAR        AS ChargeFrequency,
  ChargePeriodStart::DATE         AS ChargePeriodStart,
  ChargePeriodEnd::DATE           AS ChargePeriodEnd,
  ConsumedQuantity::DOUBLE        AS ConsumedQuantity,
  ConsumedUnit::VARCHAR           AS ConsumedUnit,
  ContractedCost::DOUBLE          AS ContractedCost,
  ContractedUnitPrice::DOUBLE     AS ContractedUnitPrice,
  EffectiveCost::DOUBLE           AS EffectiveCost,
  ListCost::DOUBLE                AS ListCost,
  ListUnitPrice::DOUBLE           AS ListUnitPrice,
  ResourceId::VARCHAR             AS ResourceId,
  ResourceType::VARCHAR           AS ResourceType,
  ServiceCategory::VARCHAR        AS ServiceCategory,
  ServiceName::VARCHAR            AS ServiceName,
  ServiceSubcategory::VARCHAR     AS ServiceSubcategory,
  SkuId::VARCHAR                  AS SkuId,
  SubAccountId::VARCHAR           AS SubAccountId,
  SubAccountName::VARCHAR         AS SubAccountName,
  SubAccountType::VARCHAR         AS SubAccountType,
  RegionId::VARCHAR               AS RegionId,

  MeterCategory::VARCHAR          AS MeterCategory,
  MeterSubCategory::VARCHAR       AS MeterSubCategory,
  MeterName::VARCHAR              AS MeterName,
  ResourceGroup::VARCHAR          AS ResourceGroup,
  ResourceLocation::VARCHAR       AS ResourceLocation,

  CURRENT_TIMESTAMP               AS _loaded_at
FROM source
