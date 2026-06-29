{{ config(
  materialized='view',
  tags=['focus', 'cost_and_usage', 'canonical'],
  alias='CostAndUsage'
) }}

{% set focus_cols = focus_column_list('CostAndUsage') %}
{% set select_cols = focus_cols + ['_loaded_at'] %}

{% if var('provider', 'none') != 'none' %}
  {% set provider_model = 'int_' ~ var('provider') ~ '_cost_and_usage' %}
  SELECT {{ select_cols | join(', ') }},
         '{{ var('provider') }}' AS _provider
  FROM {{ ref(provider_model) }}
{% else %}
  SELECT {{ select_cols | join(', ') }}, _provider
  FROM (
    {% for prov in var('enabled_providers', ['anthropic']) %}
    SELECT {{ select_cols | join(', ') }},
           '{{ prov }}' AS _provider
    FROM {{ ref('int_' ~ prov ~ '_cost_and_usage') }}
    {% if not loop.last %}UNION ALL{% endif %}
    {% endfor %}
  )
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY _provider, ChargePeriodStart, ServiceName, SubAccountId, ChargeDescription
    ORDER BY _loaded_at DESC
  ) = 1
{% endif %}
