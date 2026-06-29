{{ config(
  materialized='view',
  tags=['focus', 'invoice_detail', 'canonical'],
  alias='InvoiceDetail'
) }}

WITH stg AS (
  SELECT * FROM {{ ref('stg_invoice_detail') }}
)

SELECT
  CAST(NULL AS DOUBLE) AS BilledCost,
  CAST(NULL AS VARCHAR) AS BillingAccountId,
  CAST(NULL AS VARCHAR) AS BillingCurrency,
  CAST(NULL AS TIMESTAMP) AS BillingPeriodEnd,
  CAST(NULL AS TIMESTAMP) AS BillingPeriodStart,
  CAST(NULL AS VARCHAR) AS ChargeCategory,
  CAST(NULL AS TIMESTAMP) AS InvoiceDetailCreated,
  CAST(NULL AS VARCHAR) AS InvoiceDetailDescription,
  CAST(NULL AS VARCHAR) AS InvoiceDetailGrain,
  CAST(NULL AS VARCHAR) AS InvoiceDetailId,
  CAST(NULL AS TIMESTAMP) AS InvoiceDetailLastUpdated,
  CAST(NULL AS VARCHAR) AS InvoiceId,
  CAST(NULL AS TIMESTAMP) AS InvoiceIssueDate,
  CAST(NULL AS VARCHAR) AS InvoiceIssuerName,
  CAST(NULL AS VARCHAR) AS InvoiceIssueStatus,
  CAST(NULL AS VARCHAR) AS PaymentCurrency,
  CAST(NULL AS DOUBLE) AS PaymentCurrencyBilledCost,
  CAST(NULL AS VARCHAR) AS PaymentCurrencyInvoiceDetailId,
  CAST(NULL AS TIMESTAMP) AS PaymentDueDate,
  CAST(NULL AS VARCHAR) AS PaymentTerms,
  CAST(NULL AS VARCHAR) AS PurchaseOrderNumber,
  CAST(NULL AS VARCHAR) AS ReferenceInvoiceId
FROM stg
WHERE 1=0
