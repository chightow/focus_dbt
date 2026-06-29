# focus_dbt — Filter the Garbage

Map irregular cloud/AI provider billing data to [FOCUS](https://focus.finops.org/) 1.4 using dbt + DuckDB.

## Providers

| Provider | Data Format | Billing Model | FOCUS ChargeFrequency | FOCUS Compliance |
|---|---|---|---|---|---|
| **Anthropic** | JSON (NDJSON) | Usage-based (tokens + requests) | Usage-Based | ✅ Manual mapping |
| **GitHub Copilot** | CSV | Subscription (seats) + Usage (AI credits) | Recurring + Usage-Based | ✅ Manual mapping |
| **Azure AI** | CSV (Azure FOCUS) | Usage-based (tokens + compute) | Usage-Based | ✅ Native FOCUS export |
| **AWS Bedrock** | CSV (CUR 2.0) | Usage-based (tokens + provisioned) | Usage-Based | ❌ **CUR 2.0 — snake_case prefix soup** |

## Architecture

```
Provider Data (JSON / CSV)
    |
    | DuckDB native readers (read_json_auto / read_csv_auto)
    v
┌──────────────────────────────────────────┐
│ staging/                                 │
│ stg_anthropic_usage / stg_anthropic_cost │  UNNEST nested API JSON
│ stg_copilot_usage / stg_copilot_billing  │  Flat CSV columns
└──────────────────────────────────────────┘
    |
    | Provider-specific → FOCUS column mapping
    v
┌──────────────────────────────────────────┐
│ intermediate/providers/                  │
│ anthropic/int_anthropic_cost_and_usage   │  UNPIVOT token types + cost join
│ github/int_copilot_cost_and_usage        │  Seats (Recurring) + Credits (Usage-Based)
│ azure/int_azure_ai_cost_and_usage        │  Native FOCUS (1:1 mapping)
│ aws/int_aws_cur_cost_and_usage           │  Snake_case → FOCUS (painful)
└──────────────────────────────────────────┘
    |
    v
┌──────────────────────────────────────────┐
│ focus/CostAndUsage                       │  Provider-agnostic UNION ALL
└──────────────────────────────────────────┘
    |
    | dbt tests (auto-generated from FOCUS 1.4 spec)
    v
┌──────────────────────────────────────────┐
│ validate/                                │  Type, format, range, presence checks
└──────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Generate all sample data
python ../scripts/generate_sample_data.py

# 2. Install dbt deps
dbt deps

# 3. Run a specific provider
dbt build --vars '{provider: anthropic}'
dbt build --vars '{provider: copilot}'
dbt build --vars '{provider: azure_ai}'
dbt build --vars '{provider: aws_cur}'

# 4. Or run all four
dbt build
```

## Anthropic

The Anthropic Usage API returns nested JSON with per-bucket, per-model token counts.
The Cost API returns per-token-type costs.

### Mapping
- 5 token types (uncached input, cache read, cache create 1h/5m, output) + web_search requests → separate FOCUS rows
- Cost joined on `cost_key` (maps usage fields → cost token_type values)
- `ServiceName` = model name, `SubAccountId` = workspace ID

## GitHub Copilot

GitHub's enhanced billing platform exports CSVs with two data sources:
1. **AI credit usage** — per-user, per-model API consumption with gross/net amounts
2. **Seat assignments** — per-user subscription with plan type and monthly cost

### Mapping
- **Seat charges**: `ChargeFrequency` = 'Recurring', `ConsumedUnit` = 'Seats', per-user monthly fee
- **AI credits**: `ChargeFrequency` = 'Usage-Based', per-request consumption with `ContractedUnitPrice` = net_amount / quantity
- `ServiceName` = 'GitHub Copilot', `SubAccountId` = user login

## AWS Bedrock — CUR 2.0 Only (Not in AWS FOCUS Export)

AWS Data Exports offers **FOCUS 1.0 and 1.2 exports** alongside CUR 2.0. But Bedrock — including provisioned throughput, IAM user/resource details, and newer features — was only added to **CUR 2.0**, not the FOCUS export schema. If you want Bedrock in FOCUS format, you have to use CUR 2.0 and map it yourself:

- `line_item/UnblendedCost` → `BilledCost`
- `line_item/UsageAccountId` → `BillingAccountId`
- `product/ProductName` → `ServiceName`
- `bill/BillingPeriodStartDate` → `BillingPeriodStart`

No `ChargeCategory`, `ChargeClass`, `ChargeFrequency`, or `InvoiceIssuerName` — all derived in the intermediate model.

**AWS Data Exports has FOCUS. Bedrock just wasn't added to it.**

## Sample Data

| File | Format | Records | Source |
|---|---|---|---|
| `data/anthropic_usage.json` | NDJSON | 4 buckets | Simulated Usage API |
| `data/anthropic_cost.json` | NDJSON | 4 buckets | Simulated Cost API |
| `data/copilot_usage.csv` | CSV | 35 rows | Simulated billing export |
| `data/copilot_billing.csv` | CSV | 10 rows | Simulated seat export |
| `data/azure_ai.csv` | CSV | 95 rows | Azure FOCUS export (OpenAI + AI Foundry) |
| `data/aws_cur.csv` | CSV | 60 rows | AWS CUR 2.0 (Bedrock only — snake_case edition) |

## FOCUS 1.4 Validator Results

Both providers pass the full FOCUS 1.4 spec validation suite (auto-generated):
- Type checks (string, decimal, datetime, JSON)
- Format checks (numeric, datetime, currency, unit, key-value)
- Not-null (ColumnPresent) on required columns
- National currency codes (ISO 4217)
- Cross-column consistency

## Adding a Provider

1. Add sample data to `data/` (CSV or JSON)
2. Create `models/staging/stg_{provider}_*.sql` — ingest with `focus_read_csv` / `focus_read_json`
3. Add schema manifest to `macros/map/focus_schema.sql` for `focus_schema_assert` test
4. Create `models/intermediate/providers/{provider}/int_{provider}_cost_and_usage.sql` — map every FOCUS column
5. Add to `enabled_providers` in `dbt_project.yml`

## Requirements

- Python 3.10+
- `pip install dbt-duckdb`
