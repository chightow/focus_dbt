{{ config(
  materialized='view',
  tags=['staging', 'aws', 'cur']
) }}

WITH source AS (
  SELECT *
  FROM {{ focus_read_csv(var('aws_cur_path', 'data/aws_cur.csv')) }}
)

SELECT
  "bill/BillingPeriodStartDate"::TIMESTAMP     AS BillingPeriodStartDate,
  "bill/BillingPeriodEndDate"::TIMESTAMP       AS BillingPeriodEndDate,
  "line_item/UsageAccountId"::VARCHAR          AS UsageAccountId,
  "line_item/LineItemType"::VARCHAR            AS LineItemType,
  "line_item/UsageStartDate"::TIMESTAMP        AS UsageStartDate,
  "line_item/UsageEndDate"::TIMESTAMP          AS UsageEndDate,
  "line_item/ProductCode"::VARCHAR             AS ProductCode,
  "line_item/UsageType"::VARCHAR               AS UsageType,
  "line_item/Operation"::VARCHAR               AS Operation,
  "line_item/UsageAmount"::DOUBLE              AS UsageAmount,
  "line_item/UnblendedCost"::DOUBLE            AS UnblendedCost,
  "line_item/NetUnblendedCost"::DOUBLE         AS NetUnblendedCost,
  "line_item/CurrencyCode"::VARCHAR            AS CurrencyCode,
  "line_item/LineItemDescription"::VARCHAR     AS LineItemDescription,
  "line_item/ResourceId"::VARCHAR              AS ResourceId,
  "product/ProductName"::VARCHAR               AS ProductName,
  "product/Region"::VARCHAR                    AS Region,
  "product/InstanceType"::VARCHAR              AS InstanceType,
  "pricing/Unit"::VARCHAR                      AS PricingUnit,
  "pricing/Term"::VARCHAR                      AS PricingTerm,
  CURRENT_TIMESTAMP                            AS _loaded_at
FROM source
