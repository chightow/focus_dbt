{% macro focus_rename_map(source_relation, column_map) %}
  {{ return(adapter.dispatch('focus_rename_map', 'focus_validator_dbt')(source_relation, column_map)) }}
{% endmacro %}

{% macro default__focus_rename_map(source_relation, column_map) %}
  SELECT
    {% for target_col, source_col in column_map.items() %}
      {% if source_col is mapping %}
        {% if source_col['type'] == 'cast' %}
      CAST({{ source_relation }}."{{ source_col['source'] }}" AS {{ source_col['target_type'] }}) AS "{{ target_col }}"
        {% elif source_col['type'] == 'coalesce' %}
      COALESCE({{ source_relation }}."{{ source_col['source'] }}", {{ source_col['default'] }}) AS "{{ target_col }}"
        {% elif source_col['type'] == 'expression' %}
      {{ source_col['expr'] }} AS "{{ target_col }}"
        {% elif source_col['type'] == 'constant' %}
      CAST('{{ source_col['value'] }}' AS {{ source_col.get('target_type', 'VARCHAR') }}) AS "{{ target_col }}"
        {% elif source_col['type'] == 'concat' %}
      CONCAT({{ source_col['parts'] | join(', ') }}) AS "{{ target_col }}"
        {% endif %}
      {% else %}
      {{ source_relation }}."{{ source_col }}" AS "{{ target_col }}"
      {% endif %}
      {% if not loop.last %},{% endif %}
    {% endfor %}
{% endmacro %}

{% macro focus_column_list(dataset) %}
  {{ return(adapter.dispatch('focus_column_list', 'focus_validator_dbt')(dataset)) }}
{% endmacro %}

{% macro default__focus_column_list(dataset) %}
  {% set columns = {
    'CostAndUsage': [
      'BilledCost','BillingAccountId','BillingAccountName','BillingAccountType',
      'BillingCurrency','BillingPeriodStart','BillingPeriodEnd','ChargeCategory',
      'ChargeClass','ChargeDescription','ChargeFrequency','ChargePeriodStart',
      'ChargePeriodEnd','CommitmentDiscountCategory','CommitmentDiscountId',
      'CommitmentDiscountName','CommitmentDiscountQuantity','CommitmentDiscountStatus',
      'CommitmentDiscountType','CommitmentDiscountUnit','ConsumedQuantity',
      'ConsumedUnit','ContractedCost','ContractedUnitPrice','EffectiveCost',
      'ListCost','ListUnitPrice','PricingCategory','PricingCurrency',
      'PricingQuantity','PricingUnit','ServiceCategory','ServiceName',
      'ServiceSubcategory','SkuId','SkuMeter','SkuPriceDetails','SkuPriceId',
      'SubAccountId','SubAccountName','SubAccountType','AvailabilityZone',
      'CapacityReservationId','CapacityReservationStatus','ResourceId',
      'ResourceName','ResourceType','RegionId','RegionName','Tags',
      'InvoiceId','InvoiceIssuerName','InvoiceDetailId','AllocatedResourceId',
      'AllocatedResourceName','AllocatedMethodId','AllocatedMethodDetails',
      'AllocatedTags','ContractApplied','CommitmentProgramEligibilityDetails',
      'HostProviderName','ServiceProviderName'
    ],
    'BillingPeriod': [
      'BillingPeriodCreated','BillingPeriodEnd','BillingPeriodLastUpdated',
      'BillingPeriodStart','BillingPeriodStatus','InvoiceIssuerName'
    ],
    'InvoiceDetail': [
      'BilledCost','BillingAccountId','BillingCurrency','BillingPeriodEnd',
      'BillingPeriodStart','ChargeCategory','InvoiceDetailCreated',
      'InvoiceDetailDescription','InvoiceDetailGrain','InvoiceDetailId',
      'InvoiceDetailLastUpdated','InvoiceId','InvoiceIssueDate',
      'InvoiceIssuerName','InvoiceIssueStatus','PaymentCurrency',
      'PaymentCurrencyBilledCost','PaymentCurrencyInvoiceDetailId',
      'PaymentDueDate','PaymentTerms','PurchaseOrderNumber','ReferenceInvoiceId'
    ],
    'ContractCommitment': [
      'BillingCurrency','ContractCommitmentApplicability',
      'ContractCommitmentBenefitCategory','ContractCommitmentCategory',
      'ContractCommitmentCost','ContractCommitmentCreated',
      'ContractCommitmentDescription','ContractCommitmentDiscountPercentage',
      'ContractCommitmentDurationType','ContractCommitmentFulfillmentInterval',
      'ContractCommitmentId','ContractCommitmentLastUpdated',
      'ContractCommitmentLifecycleStatus','ContractCommitmentModel',
      'ContractCommitmentOfferCategory','ContractCommitmentPaymentInterval',
      'ContractCommitmentPaymentModel','ContractCommitmentPaymentUpfrontPercentage',
      'ContractCommitmentPeriodEnd','ContractCommitmentPeriodStart',
      'ContractCommitmentQuantity','ContractCommitmentType',
      'ContractCommitmentUnit','ContractId','ContractPeriodEnd',
      'ContractPeriodStart','InvoiceIssuerName','PricingCurrency',
      'PricingCurrencyContractCommitmentCost','ServiceProviderName'
    ]
  } %}
  {{ return(columns[dataset] | default([])) }}
{% endmacro %}

{% macro focus_type_map(column_name, source_type) %}
  {{ return(adapter.dispatch('focus_type_map', 'focus_validator_dbt')(column_name, source_type)) }}
{% endmacro %}

{% macro default__focus_type_map(column_name, source_type) %}
  {% set type_overrides = {
    'BilledCost': 'DOUBLE',
    'ContractedCost': 'DOUBLE',
    'EffectiveCost': 'DOUBLE',
    'ListCost': 'DOUBLE',
    'ContractedUnitPrice': 'DOUBLE',
    'ListUnitPrice': 'DOUBLE',
    'PricingQuantity': 'DOUBLE',
    'ConsumedQuantity': 'DOUBLE',
    'CommitmentDiscountQuantity': 'DOUBLE',
    'BillingPeriodStart': 'TIMESTAMP',
    'BillingPeriodEnd': 'TIMESTAMP',
    'ChargePeriodStart': 'TIMESTAMP',
    'ChargePeriodEnd': 'TIMESTAMP',
    'ContractCommitmentPeriodStart': 'TIMESTAMP',
    'ContractCommitmentPeriodEnd': 'TIMESTAMP',
    'ContractPeriodStart': 'TIMESTAMP',
    'ContractPeriodEnd': 'TIMESTAMP',
    'InvoiceDetailCreated': 'TIMESTAMP',
    'InvoiceDetailLastUpdated': 'TIMESTAMP',
    'InvoiceIssueDate': 'TIMESTAMP',
    'PaymentDueDate': 'TIMESTAMP',
    'BillingPeriodCreated': 'TIMESTAMP',
    'BillingPeriodLastUpdated': 'TIMESTAMP',
    'AllocatedMethodDetails': 'JSON',
    'ContractApplied': 'JSON',
    'CommitmentProgramEligibilityDetails': 'JSON',
    'ContractCommitmentApplicability': 'JSON'
  } %}
  {{ return(type_overrides.get(column_name, source_type)) }}
{% endmacro %}

{% macro focus_select_expr(dataset, source_name) %}
  {{ return(adapter.dispatch('focus_select_expr', 'focus_validator_dbt')(dataset, source_name)) }}
{% endmacro %}

{% macro default__focus_select_expr(dataset, source_name) %}
  {% set cols = focus_column_list(dataset) %}
  SELECT
  {% for col in cols %}
    {{ source_name }}."{{ col }}"
    {% if not loop.last %},{% endif %}
  {% endfor %}
  FROM {{ source_name }}
{% endmacro %}

{% macro focus_apply_mapping(source_relation, mapping_dict, dataset) %}
  {{ return(adapter.dispatch('focus_apply_mapping', 'focus_validator_dbt')(source_relation, mapping_dict, dataset)) }}
{% endmacro %}

{% macro default__focus_apply_mapping(source_relation, mapping_dict, dataset) %}
  {% set focus_cols = focus_column_list(dataset) %}
  SELECT
    {% for col in focus_cols %}
      {% if col in mapping_dict %}
        {% set src = mapping_dict[col] %}
        {% if src is mapping %}
          {% if src['type'] == 'cast' %}
    CAST({{ source_relation }}."{{ src['source'] }}" AS {{ src['target_type'] }}) AS "{{ col }}"
          {% elif src['type'] == 'coalesce' %}
    COALESCE({{ source_relation }}."{{ src['source'] }}", {{ src['default'] }}) AS "{{ col }}"
          {% elif src['type'] == 'expression' %}
    {{ src['expr'] }} AS "{{ col }}"
          {% elif src['type'] == 'constant' %}
    CAST('{{ src['value'] }}' AS {{ src.get('target_type', 'VARCHAR') }}) AS "{{ col }}"
          {% elif src['type'] == 'concat' %}
    CONCAT({{ src['parts'] | join(', ') }}) AS "{{ col }}"
          {% endif %}
        {% else %}
    {{ source_relation }}."{{ src }}" AS "{{ col }}"
        {% endif %}
      {% else %}
    CAST(NULL AS {{ focus_type_map(col, 'VARCHAR') }}) AS "{{ col }}"
      {% endif %}
      {% if not loop.last %},{% endif %}
    {% endfor %}
{% endmacro %}
