{% macro focus_test_config(severity='error', tags=[]) %}
  {{ config(severity=severity, tags=tags) }}
{% endmacro %}

{% test focus_type_string(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'type']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) != 'VARCHAR'
{% endtest %}

{% test focus_type_decimal(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'type']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) NOT IN ('DOUBLE', 'DECIMAL', 'FLOAT', 'BIGINT', 'INTEGER', 'HUGEINT', 'SMALLINT', 'TINYINT')
{% endtest %}

{% test focus_type_datetime(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'type']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) NOT LIKE 'TIMESTAMP%'
    AND typeof({{ column_name }}) NOT LIKE 'DATE%'
{% endtest %}

{% test focus_type_json(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'type']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) != 'STRUCT'
{% endtest %}

{% test focus_format_string(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) != 'VARCHAR'
{% endtest %}

{% test focus_format_numeric(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) NOT IN ('DOUBLE', 'DECIMAL', 'FLOAT', 'BIGINT', 'INTEGER', 'HUGEINT', 'SMALLINT', 'TINYINT')
{% endtest %}

{% test focus_format_datetime(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  WITH invalid AS (
    SELECT {{ column_name }}
    FROM {{ model }}
    WHERE {{ column_name }} IS NOT NULL
      AND TRY_STRPTIME({{ column_name }}::VARCHAR, '%Y-%m-%dT%H:%M:%S%z') IS NULL
      AND TRY_STRPTIME({{ column_name }}::VARCHAR, '%Y-%m-%dT%H:%M:%SZ') IS NULL
      AND TRY_STRPTIME({{ column_name }}::VARCHAR, '%Y-%m-%d %H:%M:%S') IS NULL
      AND TRY_STRPTIME({{ column_name }}::VARCHAR, '%Y-%m-%d') IS NULL
  )
  SELECT * FROM invalid
{% endtest %}

{% test focus_format_currency(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) != 'VARCHAR'
{% endtest %}

{% test focus_format_unit(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND typeof({{ column_name }}) != 'VARCHAR'
{% endtest %}

{% test focus_format_key_value(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND {{ column_name }} !~ '^[A-Za-z0-9_]+:[A-Za-z0-9_]+$'
{% endtest %}

{% test focus_format_json(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'format']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND TRY_CAST({{ column_name }} AS JSON) IS NULL
{% endtest %}

{% test focus_regex_match(model, column_name, pattern) %}
  {{ focus_test_config(severity='error', tags=['focus', 'regex']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND {{ column_name }}::VARCHAR !~ pattern
{% endtest %}

{% test focus_national_currency(model, column_name, values) %}
  {{ focus_test_config(severity='error', tags=['focus', 'currency']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND {{ column_name }} NOT IN (
      {% for v in values -%}
        '{{ v }}'{% if not loop.last %}, {% endif %}
      {%- endfor %}
    )
{% endtest %}

{% test focus_greater_or_equal(model, column_name, threshold) %}
  {{ focus_test_config(severity='error', tags=['focus', 'range']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND CAST({{ column_name }} AS DOUBLE) < {{ threshold }}
{% endtest %}

{% test focus_less_or_equal(model, column_name, threshold) %}
  {{ focus_test_config(severity='error', tags=['focus', 'range']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND CAST({{ column_name }} AS DOUBLE) > {{ threshold }}
{% endtest %}

{% test focus_decimal_value(model, column_name) %}
  {{ focus_test_config(severity='error', tags=['focus', 'type']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND TRY_CAST({{ column_name }} AS DOUBLE) IS NULL
    AND {{ column_name }}::VARCHAR !~ '^-?\d+(\.\d+)?$'
{% endtest %}

{% test focus_column_equality(model, column_a, column_b) %}
  {{ focus_test_config(severity='error', tags=['focus', 'cross_column']) }}
  SELECT {{ column_a }}, {{ column_b }}
  FROM {{ model }}
  WHERE {{ column_a }} IS NOT NULL
    AND {{ column_b }} IS NOT NULL
    AND CAST({{ column_a }} AS VARCHAR) != CAST({{ column_b }} AS VARCHAR)
{% endtest %}

{% test focus_multiplication_equals(model, column_a, column_b, result_column, tolerance) %}
  {{ focus_test_config(severity='error', tags=['focus', 'cross_column']) }}
  SELECT {{ column_a }}, {{ column_b }}, {{ result_column }}
  FROM {{ model }}
  WHERE {{ column_a }} IS NOT NULL
    AND {{ column_b }} IS NOT NULL
    AND {{ result_column }} IS NOT NULL
    AND ABS(CAST({{ column_a }} AS DOUBLE) * CAST({{ column_b }} AS DOUBLE) - CAST({{ result_column }} AS DOUBLE)) > {{ tolerance }}
{% endtest %}

{% test focus_string_ends_with(model, column_name, value) %}
  {{ focus_test_config(severity='error', tags=['focus', 'string']) }}
  SELECT {{ column_name }}
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND RIGHT({{ column_name }}::VARCHAR, LEN('{{ value }}')) != '{{ value }}'
{% endtest %}

{% test focus_distinct_count(model, column_a, column_b, expected_count) %}
  {{ focus_test_config(severity='error', tags=['focus', 'distinct']) }}
  WITH counts AS (
    SELECT COUNT(DISTINCT {{ column_b }}) AS distinct_count
    FROM {{ model }}
    WHERE {{ column_a }} IS NOT NULL
  )
  SELECT distinct_count
  FROM counts
  WHERE distinct_count != {{ expected_count }}
{% endtest %}

{% test focus_column_comparison(model, column_a, column_b, comparator) %}
  {{ focus_test_config(severity='error', tags=['focus', 'cross_column']) }}
  SELECT {{ column_a }}, {{ column_b }}
  FROM {{ model }}
  WHERE {{ column_a }} IS NOT NULL
    AND {{ column_b }} IS NOT NULL
    {% if comparator == '!=' %}
    AND CAST({{ column_a }} AS VARCHAR) != CAST({{ column_b }} AS VARCHAR)
    {% elif comparator == '==' %}
    AND CAST({{ column_a }} AS VARCHAR) == CAST({{ column_b }} AS VARCHAR)
    {% elif comparator == '>' %}
    AND CAST({{ column_a }} AS DOUBLE) <= CAST({{ column_b }} AS DOUBLE)
    {% elif comparator == '<' %}
    AND CAST({{ column_a }} AS DOUBLE) >= CAST({{ column_b }} AS DOUBLE)
    {% elif comparator == '>=' %}
    AND CAST({{ column_a }} AS DOUBLE) < CAST({{ column_b }} AS DOUBLE)
    {% elif comparator == '<=' %}
    AND CAST({{ column_a }} AS DOUBLE) > CAST({{ column_b }} AS DOUBLE)
    {% endif %}
{% endtest %}
