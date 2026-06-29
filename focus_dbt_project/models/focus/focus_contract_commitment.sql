{{ config(
  materialized='view',
  tags=['focus', 'contract_commitment', 'canonical'],
  alias='ContractCommitment'
) }}

WITH stg AS (
  SELECT * FROM {{ ref('stg_contract_commitment') }}
)

SELECT
  CAST(NULL AS VARCHAR) AS BillingCurrency,
  CAST(NULL AS JSON) AS ContractCommitmentApplicability,
  CAST(NULL AS VARCHAR) AS ContractCommitmentBenefitCategory,
  CAST(NULL AS VARCHAR) AS ContractCommitmentCategory,
  CAST(NULL AS DOUBLE) AS ContractCommitmentCost,
  CAST(NULL AS TIMESTAMP) AS ContractCommitmentCreated,
  CAST(NULL AS VARCHAR) AS ContractCommitmentDescription,
  CAST(NULL AS DOUBLE) AS ContractCommitmentDiscountPercentage,
  CAST(NULL AS VARCHAR) AS ContractCommitmentDurationType,
  CAST(NULL AS VARCHAR) AS ContractCommitmentFulfillmentInterval,
  CAST(NULL AS VARCHAR) AS ContractCommitmentId,
  CAST(NULL AS TIMESTAMP) AS ContractCommitmentLastUpdated,
  CAST(NULL AS VARCHAR) AS ContractCommitmentLifecycleStatus,
  CAST(NULL AS VARCHAR) AS ContractCommitmentModel,
  CAST(NULL AS VARCHAR) AS ContractCommitmentOfferCategory,
  CAST(NULL AS VARCHAR) AS ContractCommitmentPaymentInterval,
  CAST(NULL AS VARCHAR) AS ContractCommitmentPaymentModel,
  CAST(NULL AS DOUBLE) AS ContractCommitmentPaymentUpfrontPercentage,
  CAST(NULL AS TIMESTAMP) AS ContractCommitmentPeriodEnd,
  CAST(NULL AS TIMESTAMP) AS ContractCommitmentPeriodStart,
  CAST(NULL AS DOUBLE) AS ContractCommitmentQuantity,
  CAST(NULL AS VARCHAR) AS ContractCommitmentType,
  CAST(NULL AS VARCHAR) AS ContractCommitmentUnit,
  CAST(NULL AS VARCHAR) AS ContractId,
  CAST(NULL AS TIMESTAMP) AS ContractPeriodEnd,
  CAST(NULL AS TIMESTAMP) AS ContractPeriodStart,
  CAST(NULL AS VARCHAR) AS InvoiceIssuerName,
  CAST(NULL AS VARCHAR) AS PricingCurrency,
  CAST(NULL AS DOUBLE) AS PricingCurrencyContractCommitmentCost,
  CAST(NULL AS VARCHAR) AS ServiceProviderName
FROM stg
WHERE 1=0
