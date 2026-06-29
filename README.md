# focus_dbt — Filter the Garbage

**Map irregular cloud/AI billing data to [FOCUS](https://focus.finops.org/) 1.4 using DuckDB + dbt.**

Every AI provider ships billing data in a different shape:
- Anthropic: deeply nested JSON with UNNESTs
- Copilot: flat CSVs from billing exports
- Azure: FOCUS-native (already compliant)
- AWS: CUR 2.0 snake_case prefix soup

This repo shows how DuckDB + dbt can ingest any of them, normalize to FOCUS, and validate the output against the spec — so you can **filter the garbage** before it reaches your FinOps pipeline.

## Providers

| Provider | Format | Ingestion | Validation |
|---|---|---|---|
| **Anthropic** | NDJSON | `CROSS JOIN UNNEST` | Schema assert + type checks |
| **Copilot** | CSV | `read_csv_auto` | Schema assert + type checks |
| **Azure AI** | CSV (FOCUS) | `read_csv_auto` | Nearly 1:1 |
| **AWS Bedrock** | CSV (CUR 2.0) | `read_csv_auto` with quoted `/` columns | Snake_case → FOCUS |

## Architecture

```
Provider Data (JSON / CSV / whatever)
    |
    | DuckDB native readers (no ETL tool)
    v
staging/            ← raw ingestion, type casting
intermediate/       ← provider → FOCUS column mapping
focus/              ← canonical FOCUS output
validate/           ← FOCUS spec tests (auto-generated)
    |
    v
Pass / Fail report  ← schema drift? type mismatch? caught here
```

## Quick Start

```bash
cd focus_dbt_project
pip install dbt-duckdb
python ../scripts/generate_sample_data.py
dbt deps
dbt build --vars '{provider: anthropic}'
dbt build   # all 4 providers + FOCUS spec validation
```

## What filter the garbage means

- **`focus_schema_assert`** — tests on every staging model that fail if an unexpected column appears (API added a field? You'll know.)
- **20+ custom generic tests** — type checks, format checks, range checks, cross-column consistency
- **Auto-generated validate layer** — pulled from the FOCUS 1.4 model JSON, every column's spec requirements turned into dbt tests
- **Irregular sources, regular output** — different JSON shapes, CSV formats, column naming conventions all land in the same FOCUS schema

## Caveats

100% AI-generated. ~$0.15 in API costs. Data is fabricated. CostAndUsage only (not BillingPeriod/InvoiceDetail/ContractCommitment). Review before using.

## Map your own

Add a provider in 4 files:

1. `data/{provider}.csv` — your sample data
2. `models/staging/stg_{provider}.sql` — ingest + cast
3. `models/intermediate/providers/{provider}/int_{provider}_cost_and_usage.sql` — map every FOCUS column
4. Update `macros/map/focus_schema.sql` with your schema manifest

## License

MIT — do whatever.
