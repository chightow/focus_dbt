# AI → FOCUS Mapping with dbt

**100% AI-generated slop for ~$0.15 in API costs.**

This repo demonstrates how to map cloud/AI provider billing data to the [FOCUS](https://focus.finops.org/) 1.4 spec using dbt + DuckDB. It was entirely produced by an LLM in a single session as a pattern demonstration. Not production code. Not validated by anyone who actually knows what they're doing.

## Providers

| Provider | Data Format | Status | Real Data? |
|---|---|---|---|
| **Anthropic** | NDJSON | Working | Fabricated |
| **GitHub Copilot** | CSV | Working | Fabricated |
| **Azure AI** | CSV | Working | Fabricated |
| **AWS Bedrock** | CSV (CUR 2.0) | Working | Fabricated, based on docs |

## Why

FOCUS is a decent spec. No one implements it well. This shows the mapping pattern for 4 AI providers so someone could adapt it to real data without starting from scratch.

## Requirements

```bash
pip install dbt-duckdb
```

## Quick Start

```bash
cd focus_dbt_project
python ../scripts/generate_sample_data.py
dbt deps
dbt build --vars '{provider: anthropic}'
dbt build   # all 4 providers
```

## What's Here

```
scripts/generate_sample_data.py   — makes up fake data that looks like real APIs
focus_dbt_project/
  models/staging/                  — raw ingestion (JSON UNNEST, CSV read)
  models/intermediate/providers/   — 4 provider → FOCUS mappings
  models/focus/                    — canonical FOCUS output
  macros/                          — DuckDB helpers + FOCUS spec tests
```

## Caveats

- **Data is fake.** Sample data mimics API shapes but has no real billing values.
- **AI-generated.** Every line of SQL and Python was written by an LLM. Review before using.
- **CostAndUsage only.** The spec has 4 datasets; this only addresses 1.
- **Commitment discounts not handled.** Reservations, Savings Plans, annual commitments — not modeled.
- **AWS Bedrock gap.** AWS has FOCUS exports in Data Exports. Bedrock wasn't added to them. That's the mapping gap this project exists to work around.

## License

Do whatever you want. It's AI slop.
