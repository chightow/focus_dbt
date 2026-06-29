{% macro focus_schema_manifest(provider) %}
  {{ return(adapter.dispatch('focus_schema_manifest', 'focus_validator_dbt')(provider)) }}
{% endmacro %}

{% macro default__focus_schema_manifest(provider) %}
  {% set manifests = {
    'anthropic_usage': {
      'allowed': [
        'bucket_start', 'bucket_end',
        'uncached_input_tokens', 'cache_read_input_tokens', 'output_tokens',
        'cache_creation_1h_tokens', 'cache_creation_5m_tokens',
        'web_search_requests',
        'model', 'api_key_id', 'workspace_id', 'account_id',
        'service_account_id', 'service_tier', 'context_window', 'inference_geo',
        '_loaded_at',
      ],
      'ignored': ['has_more', 'next_page'],
    },
    'anthropic_cost': {
      'allowed': [
        'bucket_start', 'bucket_end',
        'amount_cents', 'amount_usd', 'currency',
        'cost_type', 'description', 'model', 'token_type',
        'workspace_id', 'service_tier', 'context_window', 'inference_geo',
        '_loaded_at',
      ],
      'ignored': ['has_more', 'next_page'],
    },
    'copilot_usage': {
      'allowed': [
        'usage_date', 'product', 'sku', 'model', 'unit_type',
        'quantity', 'gross_amount', 'discount_amount', 'net_amount',
        'organization', 'user_name', 'team', '_loaded_at',
      ],
      'ignored': [],
    },
    'copilot_billing': {
      'allowed': [
        'user_name', 'organization', 'team', 'plan_type',
        'seat_created_at', 'last_activity_at', 'last_activity_editor',
        'monthly_cost', '_loaded_at',
      ],
      'ignored': [],
    },
    'aws_cur': {
      'allowed': [
        'BillingPeriodStartDate', 'BillingPeriodEndDate',
        'UsageAccountId', 'LineItemType',
        'UsageStartDate', 'UsageEndDate',
        'ProductCode', 'UsageType', 'Operation',
        'UsageAmount', 'UnblendedCost', 'NetUnblendedCost',
        'CurrencyCode', 'LineItemDescription',
        'ResourceId',
        'ProductName', 'Region', 'InstanceType',
        'PricingUnit', 'PricingTerm',
        '_loaded_at',
      ],
      'ignored': [],
    },
    'azure_ai': {
      'allowed': [
        'BilledCost', 'BillingAccountId', 'BillingAccountName',
        'BillingCurrency', 'BillingPeriodStart', 'BillingPeriodEnd',
        'ChargeCategory', 'ChargeClass', 'ChargeDescription',
        'ChargeFrequency', 'ChargePeriodStart', 'ChargePeriodEnd',
        'ConsumedQuantity', 'ConsumedUnit',
        'ContractedCost', 'ContractedUnitPrice',
        'EffectiveCost', 'ListCost', 'ListUnitPrice',
        'ResourceId', 'ResourceType',
        'ServiceCategory', 'ServiceName', 'ServiceSubcategory',
        'SkuId',
        'SubAccountId', 'SubAccountName', 'SubAccountType',
        'RegionId',
        'MeterCategory', 'MeterSubCategory', 'MeterName',
        'ResourceGroup', 'ResourceLocation',
        '_loaded_at',
      ],
      'ignored': [],
    },
  } %}
  {{ return(manifests.get(provider, {'allowed': [], 'ignored': []})) }}
{% endmacro %}

{% test focus_schema_assert(model, manifest_key) %}
  {{ config(severity='error', tags=['schema', 'provider_check']) }}

  {% set manifest = focus_schema_manifest(manifest_key) %}
  {% set allowed = manifest['allowed'] %}
  {% set ignored = manifest['ignored'] %}

  WITH actual AS (
    SELECT column_name::VARCHAR AS column_name
    FROM (DESCRIBE {{ model }})
  ),
  expected AS (
    SELECT UNNEST([
      {% for col in allowed %}
        '{{ col }}'{{ ',' if not loop.last }}
      {% endfor %}
    ]) AS column_name
  ),
  ignored_list AS (
    SELECT UNNEST([
      {% for col in ignored %}
        '{{ col }}'{{ ',' if not loop.last }}
      {% endfor %}
    ]) AS column_name
  ),
  unexpected AS (
    SELECT a.column_name
    FROM actual a
    WHERE a.column_name NOT IN (SELECT column_name FROM expected)
      AND a.column_name NOT IN (SELECT column_name FROM ignored_list)
  )
  SELECT
    'UNEXPECTED COLUMN: ' || column_name || ' — add to manifest allowed or ignored list' AS failure_reason
  FROM unexpected
{% endtest %}
