{{ config(
  materialized='view',
  tags=['focus', 'billing_period', 'canonical'],
  alias='BillingPeriod'
) }}

WITH stg AS (
  SELECT * FROM {{ ref('stg_billing_period') }}
)

SELECT
  CAST(NULL AS TIMESTAMP) AS BillingPeriodCreated,
  CAST(NULL AS TIMESTAMP) AS BillingPeriodEnd,
  CAST(NULL AS TIMESTAMP) AS BillingPeriodLastUpdated,
  CAST(NULL AS TIMESTAMP) AS BillingPeriodStart,
  CAST(NULL AS VARCHAR) AS BillingPeriodStatus,
  CAST(NULL AS VARCHAR) AS InvoiceIssuerName
FROM stg
WHERE 1=0
