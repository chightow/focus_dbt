#!/usr/bin/env python3
"""Generate sample data for all providers.

Usage:
    python generate_sample_data.py

Output:
    focus_dbt_project/data/anthropic_usage.json
    focus_dbt_project/data/anthropic_cost.json
    focus_dbt_project/data/copilot_usage.csv
    focus_dbt_project/data/copilot_billing.csv
    focus_dbt_project/data/azure_ai.csv
"""

import csv
import json
import os
import random as _random
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent / "focus_dbt_project"
DATA_DIR = PROJECT_DIR / "data"


# ── Anthropic (JSON) ─────────────────────────────────────────────────────────

def _anthropic_usage():
    usage_map = {
        ("claude-opus-4-6", "ws-alpha"): (1500, 200, 500, 1000, 500, 10),
        ("claude-opus-4-6", "ws-beta"):  (3000, 400, 800, 2000, 1000, 5),
        ("claude-sonnet-4-6", "ws-alpha"): (4000, 600, 1200, 3000, 1500, 20),
        ("claude-sonnet-4-6", "ws-beta"):  (2500, 300, 700, 1500, 800, 8),
        ("claude-sonnet-4-6", "ws-gamma"): (1000, 100, 300, 500, 200, 3),
        ("claude-haiku-3-5-20241022", "ws-beta"):  (8000, 500, 2000, 3000, 1500, 50),
        ("claude-haiku-3-5-20241022", "ws-gamma"): (5000, 300, 1500, 2000, 1000, 30),
    }
    buckets = [
        ("2025-01-02T00:00:00Z", "2025-01-02T01:00:00Z"),
        ("2025-01-02T14:00:00Z", "2025-01-02T15:00:00Z"),
        ("2025-01-03T00:00:00Z", "2025-01-03T01:00:00Z"),
        ("2025-01-04T10:00:00Z", "2025-01-04T11:00:00Z"),
    ]
    responses = []
    for start, end in buckets:
        results = []
        for (model, ws), v in usage_map.items():
            results.append({
                "uncached_input_tokens": v[0], "cache_read_input_tokens": v[1],
                "output_tokens": v[2],
                "cache_creation": {"ephemeral_1h_input_tokens": v[3], "ephemeral_5m_input_tokens": v[4]},
                "server_tool_use": {"web_search_requests": v[5]},
                "model": model, "api_key_id": "ak-001", "workspace_id": ws,
                "account_id": "acct-focus", "service_account_id": None,
                "service_tier": "default", "context_window": "200000", "inference_geo": "us",
            })
        responses.append({"data": [{"starting_at": start, "ending_at": end, "results": results}], "has_more": False, "next_page": None})
    return responses


def _anthropic_cost():
    rates = {"uncached_input_tokens": 3.00, "cache_read_input_tokens": 0.30, "output_tokens": 15.00, "cache_creation.ephemeral_1h_input_tokens": 0.30, "cache_creation.ephemeral_5m_input_tokens": 0.15}
    qtys_map = {
        ("claude-opus-4-6", "ws-alpha"): (1500, 200, 500, 1000, 500),
        ("claude-opus-4-6", "ws-beta"):  (3000, 400, 800, 2000, 1000),
        ("claude-sonnet-4-6", "ws-alpha"): (4000, 600, 1200, 3000, 1500),
        ("claude-sonnet-4-6", "ws-beta"):  (2500, 300, 700, 1500, 800),
        ("claude-sonnet-4-6", "ws-gamma"): (1000, 100, 300, 500, 200),
        ("claude-haiku-3-5-20241022", "ws-beta"):  (8000, 500, 2000, 3000, 1500),
        ("claude-haiku-3-5-20241022", "ws-gamma"): (5000, 300, 1500, 2000, 1000),
    }
    tks = list(rates.keys())
    buckets = [
        ("2025-01-02T00:00:00Z", "2025-01-02T01:00:00Z"),
        ("2025-01-02T14:00:00Z", "2025-01-02T15:00:00Z"),
        ("2025-01-03T00:00:00Z", "2025-01-03T01:00:00Z"),
        ("2025-01-04T10:00:00Z", "2025-01-04T11:00:00Z"),
    ]
    responses = []
    for start, end in buckets:
        results = []
        for (model, ws), qtys in qtys_map.items():
            for i, tt in enumerate(tks):
                qty = qtys[i]
                if qty == 0: continue
                amt = qty * rates[tt] / 1_000_000
                results.append({"amount": f"{amt:.6f}", "currency": "USD", "cost_type": "manual", "description": "Usage costs", "model": model, "token_type": tt, "workspace_id": ws, "service_tier": "default", "context_window": "200000", "inference_geo": "us"})
        responses.append({"data": [{"starting_at": start, "ending_at": end, "results": results}], "has_more": False, "next_page": None})
    return responses


# ── GitHub Copilot (CSV) ─────────────────────────────────────────────────────

def _copilot_usage_csv():
    rows = []
    users_data = [
        ("alice", "Engineering", 500, 15.00, "claude-sonnet-4-6"),
        ("bob", "Engineering", 350, 10.50, "claude-sonnet-4-6"),
        ("carol", "Engineering", 200, 6.00, "claude-haiku-3-5-20241022"),
        ("dave", "Data Science", 400, 12.00, "claude-sonnet-4-6"),
        ("eve", "Data Science", 300, 9.00, "claude-opus-4-6"),
        ("frank", "Product", 150, 4.50, "claude-haiku-3-5-20241022"),
        ("grace", "Engineering", 450, 13.50, "claude-sonnet-4-6"),
    ]
    days = ["2025-01-06", "2025-01-07", "2025-01-08", "2025-01-09", "2025-01-10"]
    for day in days:
        for user, team, qty, amt, model in users_data:
            rows.append({"date": day, "product": "Copilot", "sku": "ai_credits", "model": model, "unit_type": "requests", "quantity": qty, "gross_amount": f"{amt:.2f}", "discount_amount": "0.00", "net_amount": f"{amt:.2f}", "organization": "myorg", "user": user, "team": team})
    return rows


def _copilot_billing_csv():
    users = [
        ("alice", "Engineering", "vscode", "2024-06-01", "business"),
        ("bob", "Engineering", "jetbrains", "2024-06-01", "business"),
        ("carol", "Engineering", "vscode", "2024-06-15", "business"),
        ("dave", "Data Science", "vscode", "2024-07-01", "business"),
        ("eve", "Data Science", "jupyter", "2024-07-01", "business"),
        ("frank", "Product", "vscode", "2024-08-01", "business"),
        ("grace", "Engineering", "neovim", "2024-09-01", "business"),
        ("henry", "Engineering", "vscode", "2024-10-01", "business"),
        ("ivy", "Design", "vscode", "2024-11-01", "enterprise"),
        ("jack", "Product", "jetbrains", "2024-11-15", "enterprise"),
    ]
    rows = []
    for user, team, editor, created, plan in users:
        monthly = 39.00 if plan == "enterprise" else 19.00
        rows.append({"user": user, "organization": "myorg", "team": team, "plan_type": plan, "seat_created_at": created, "last_activity_at": "2025-01-15T10:30:00Z", "last_activity_editor": editor, "pending_cancellation_date": "", "monthly_cost": f"{monthly:.2f}"})
    return rows


# ── Azure AI (CSV) ───────────────────────────────────────────────────────────

def _azure_ai_csv():
    """Azure Cost Management FOCUS export — AI services only (OpenAI + AI Foundry).

    Azure MCA cost exports already use FOCUS column names. We include both
    the standard FOCUS columns and Azure-specific enrichment columns.
    """
    rows = []

    subs = [
        ("sub-001", "Production AI", "rg-openai-prod", "eastus"),
        ("sub-001", "Production AI", "rg-foundry-prod", "eastus"),
        ("sub-002", "Dev/Test AI", "rg-openai-dev", "westus"),
    ]

    openai_meters = [
        ("OpenAI", "GPT-4o", "Text-Generation", "1M Tokens", 10.00),
        ("OpenAI", "GPT-4o", "Chat-Completion", "1M Tokens", 2.50),
        ("OpenAI", "GPT-4o-mini", "Text-Generation", "1M Tokens", 0.15),
        ("OpenAI", "GPT-4o-mini", "Chat-Completion", "1M Tokens", 0.60),
        ("OpenAI", "text-embedding-3-large", "Embedding", "1M Tokens", 0.13),
        ("OpenAI", "text-embedding-3-small", "Embedding", "1M Tokens", 0.02),
        ("OpenAI", "gpt-4o-realtime", "Realtime-Text", "1M Tokens", 2.50),
    ]

    foundry_meters = [
        ("Machine Learning", "ML Compute - GPU", "NC24ads A100 v4 Hours", "1 Hour", 3.40),
        ("Machine Learning", "ML Compute - GPU", "ND40rs v2 Hours", "1 Hour", 6.50),
        ("Machine Learning", "ML Endpoint - Real-time", "Endpoint Hours", "1 Hour", 0.15),
        ("Machine Learning", "ML Endpoint - Batch", "Batch Scoring", "1K Records", 0.05),
        ("Machine Learning", "ML Storage", "Managed Data", "1 GB", 0.023),
    ]

    days = ["2025-01-06", "2025-01-07", "2025-01-08", "2025-01-09", "2025-01-10"]

    import random
    rng = random.Random(42)

    for day in days:
        for sub_id, sub_name, rg, loc in subs:
            if "openai" not in rg:
                continue
            for cat, subcat, meter, unit, rate in openai_meters:
                if "eastus" in loc and "Prod" in sub_name:
                    qty = rng.randint(5, 50) * 10000
                elif "dev" in rg:
                    qty = rng.randint(1, 10) * 10000
                else:
                    qty = rng.randint(2, 20) * 10000

                cost = qty / 1_000_000 * rate
                rows.append({
                    # FOCUS columns (Azure already uses these)
                    "BilledCost": f"{cost:.4f}",
                    "BillingAccountId": sub_id,
                    "BillingAccountName": sub_name,
                    "BillingCurrency": "USD",
                    "BillingPeriodStart": day,
                    "BillingPeriodEnd": day,
                    "ChargeCategory": "Usage",
                    "ChargeClass": "Regular",
                    "ChargeDescription": f"Azure OpenAI - {subcat} - {meter}",
                    "ChargeFrequency": "Usage-Based",
                    "ChargePeriodStart": day,
                    "ChargePeriodEnd": day,
                    "ConsumedQuantity": f"{qty}",
                    "ConsumedUnit": unit,
                    "ContractedCost": f"{cost:.4f}",
                    "ContractedUnitPrice": f"{rate / 1_000_000:.10f}",
                    "EffectiveCost": f"{cost:.4f}",
                    "ListCost": f"{cost:.4f}",
                    "ListUnitPrice": f"{rate / 1_000_000:.10f}",
                    "ResourceId": f"/subscriptions/{sub_id}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{meter.lower().replace(' ','').replace('-','')}",
                    "ResourceType": "Microsoft.CognitiveServices/accounts",
                    "ServiceCategory": "AI / LLM",
                    "ServiceName": "Azure OpenAI",
                    "ServiceSubcategory": subcat,
                    "SkuId": f"openai-{subcat.lower().replace(' ','').replace('.','')}",
                    "SubAccountId": sub_id,
                    "SubAccountName": sub_name,
                    "SubAccountType": "Subscription",
                    "RegionId": loc,
                    # Azure-specific enrichment
                    "MeterCategory": cat,
                    "MeterSubCategory": subcat,
                    "MeterName": meter,
                    "ResourceGroup": rg,
                    "ResourceLocation": loc,
                })

        for sub_id, sub_name, rg, loc in subs:
            if "foundry" not in rg:
                continue
            for cat, subcat, meter, unit, rate in foundry_meters:
                if "GPU" in meter:
                    qty = rng.randint(1, 8)
                elif "Endpoint" in meter:
                    qty = rng.randint(100, 500)
                elif "Storage" in meter:
                    qty = rng.randint(50, 200)
                else:
                    qty = rng.randint(10, 100)

                cost = qty * rate
                rows.append({
                    "BilledCost": f"{cost:.4f}",
                    "BillingAccountId": sub_id,
                    "BillingAccountName": sub_name,
                    "BillingCurrency": "USD",
                    "BillingPeriodStart": day,
                    "BillingPeriodEnd": day,
                    "ChargeCategory": "Usage",
                    "ChargeClass": "Regular",
                    "ChargeDescription": f"Azure AI Foundry - {subcat} - {meter}",
                    "ChargeFrequency": "Usage-Based",
                    "ChargePeriodStart": day,
                    "ChargePeriodEnd": day,
                    "ConsumedQuantity": f"{qty}",
                    "ConsumedUnit": unit,
                    "ContractedCost": f"{cost:.4f}",
                    "ContractedUnitPrice": f"{rate:.4f}",
                    "EffectiveCost": f"{cost:.4f}",
                    "ListCost": f"{cost:.4f}",
                    "ListUnitPrice": f"{rate:.4f}",
                    "ResourceId": f"/subscriptions/{sub_id}/resourceGroups/{rg}/providers/Microsoft.MachineLearningServices/workspaces/foundry-{subcat.lower().replace(' ','').replace('-','')}",
                    "ResourceType": "Microsoft.MachineLearningServices/workspaces",
                    "ServiceCategory": "AI / LLM",
                    "ServiceName": "Azure AI Foundry",
                    "ServiceSubcategory": subcat,
                    "SkuId": f"foundry-{subcat.lower().replace(' ','').replace('-','')}",
                    "SubAccountId": sub_id,
                    "SubAccountName": sub_name,
                    "SubAccountType": "Subscription",
                    "RegionId": loc,
                    "MeterCategory": cat,
                    "MeterSubCategory": subcat,
                    "MeterName": meter,
                    "ResourceGroup": rg,
                    "ResourceLocation": loc,
                })

    return rows


# ── AWS CUR 2.0 (CSV) ────────────────────────────────────────────────────────

def _aws_cur_csv():
    """AWS CUR 2.0 export — Bedrock only.

    AWS calls this 'FOCUS 2.0' but it's snake_case prefix soup:
      bill/BillingPeriodStartDate, line_item/UsageAmount, product/ProductName, ...
    Not a single CamelCase FOCUS column name in sight. Shame.
    """
    rng = _random.Random(7)
    rows = []

    accounts = [("111111111111", "prod-ai"), ("222222222222", "dev-ml")]

    bedrock_ondemand = [
        ("claude-sonnet-v1",   0.003,   "USW2-BedrockInferenceTokens:claude-sonnet-v1"),
        ("claude-haiku-v1",    0.00025, "USW2-BedrockInferenceTokens:claude-haiku-v1"),
        ("claude-opus-v1",     0.015,   "USW2-BedrockInferenceTokens:claude-opus-v1"),
        ("llama3-70b-v1",      0.00195, "USW2-BedrockInferenceTokens:llama3-70b-v1"),
        ("titan-embedding-v1", 0.0001,  "USW2-BedrockInferenceTokens:titan-embedding-v1"),
    ]

    bedrock_provisioned = [
        ("claude-sonnet-v1", 8.64, "USW2-BedrockProvisionedThroughput:claude-sonnet-v1"),
        ("claude-haiku-v1",  1.50, "USW2-BedrockProvisionedThroughput:claude-haiku-v1"),
    ]

    days = ["2025-01-06", "2025-01-07", "2025-01-08", "2025-01-09", "2025-01-10"]

    for day in days:
        for acct, acct_name in accounts:
            mult = 1.5 if acct == "111111111111" else 0.3

            for model, rate_per_1k, usage_type in bedrock_ondemand:
                tokens = int(rng.randint(50, 500) * 1000 * mult)
                cost = (tokens / 1000) * rate_per_1k
                rows.append({
                    "bill/BillingPeriodStartDate": f"{day}T00:00:00Z",
                    "bill/BillingPeriodEndDate": f"{day}T23:59:59Z",
                    "bill/InvoiceId": "",
                    "line_item/UsageAccountId": acct,
                    "line_item/LineItemType": "Usage",
                    "line_item/UsageStartDate": f"{day}T00:00:00Z",
                    "line_item/UsageEndDate": f"{day}T23:59:59Z",
                    "line_item/ProductCode": "AmazonBedrock",
                    "line_item/UsageType": usage_type,
                    "line_item/Operation": "RunInference",
                    "line_item/UsageAmount": str(tokens),
                    "line_item/UnblendedCost": f"{cost:.6f}",
                    "line_item/NetUnblendedCost": f"{cost:.6f}",
                    "line_item/CurrencyCode": "USD",
                    "line_item/LineItemDescription": f"Bedrock inference tokens for {model}",
                    "line_item/ResourceId": "",
                    "product/ProductName": "Amazon Bedrock",
                    "product/Region": "us-west-2",
                    "product/InstanceType": "",
                    "pricing/Unit": "Units (1 unit = 1000 tokens)",
                    "pricing/RateId": f"bedrock.{model}.ondemand",
                    "pricing/Term": "OnDemand",
                    "line_item/AvailabilityZone": "",
                })

            for model, hourly_rate, usage_type in bedrock_provisioned:
                hours = rng.randint(4, 24) if acct == "111111111111" else 0
                if hours == 0:
                    continue
                cost = hours * hourly_rate
                rows.append({
                    "bill/BillingPeriodStartDate": f"{day}T00:00:00Z",
                    "bill/BillingPeriodEndDate": f"{day}T23:59:59Z",
                    "bill/InvoiceId": "",
                    "line_item/UsageAccountId": acct,
                    "line_item/LineItemType": "Usage",
                    "line_item/UsageStartDate": f"{day}T00:00:00Z",
                    "line_item/UsageEndDate": f"{day}T23:59:59Z",
                    "line_item/ProductCode": "AmazonBedrock",
                    "line_item/UsageType": usage_type,
                    "line_item/Operation": "RunProvisionedInference",
                    "line_item/UsageAmount": str(hours),
                    "line_item/UnblendedCost": f"{cost:.6f}",
                    "line_item/NetUnblendedCost": f"{cost:.6f}",
                    "line_item/CurrencyCode": "USD",
                    "line_item/LineItemDescription": f"Bedrock provisioned throughput for {model}",
                    "line_item/ResourceId": f"arn:aws:bedrock:us-west-2:{acct}:provisioned-model/{model}-{day}",
                    "product/ProductName": "Amazon Bedrock",
                    "product/Region": "us-west-2",
                    "product/InstanceType": "",
                    "pricing/Unit": "Hrs",
                    "pricing/RateId": f"bedrock.{model}.provisioned",
                    "pricing/Term": "OnDemand",
                    "line_item/AvailabilityZone": "",
                })

    return rows


# ── Writers ──────────────────────────────────────────────────────────────────

def write_json(responses, filename):
    filepath = DATA_DIR / filename
    with open(filepath, "w") as f:
        for r in responses:
            f.write(json.dumps(r) + "\n")
    print(f"  Wrote {filepath} ({os.path.getsize(filepath)} bytes, {len(responses)} rows)")


def write_csv(rows, filename):
    filepath = DATA_DIR / filename
    if not rows:
        return
    with open(filepath, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"  Wrote {filepath} ({os.path.getsize(filepath)} bytes, {len(rows)} rows)")


if __name__ == "__main__":
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    print("Generating sample Anthropic Usage data...")
    write_json(_anthropic_usage(), "anthropic_usage.json")

    print("Generating sample Anthropic Cost data...")
    write_json(_anthropic_cost(), "anthropic_cost.json")

    print("Generating sample GitHub Copilot Usage data...")
    write_csv(_copilot_usage_csv(), "copilot_usage.csv")

    print("Generating sample GitHub Copilot Billing data...")
    write_csv(_copilot_billing_csv(), "copilot_billing.csv")

    print("Generating sample Azure AI data...")
    write_csv(_azure_ai_csv(), "azure_ai.csv")

    print("Generating sample AWS CUR 2.0 Bedrock data...")
    write_csv(_aws_cur_csv(), "aws_cur.csv")

    print("Done.")
    print(f"\n  cd {PROJECT_DIR}")
    print("  dbt deps")
    print("  dbt build --vars '{provider: anthropic}'")
    print("  dbt build --vars '{provider: copilot}'")
    print("  dbt build --vars '{provider: azure_ai}'")
    print("  dbt build --vars '{provider: aws_cur}'")
    print("  dbt build --vars '{enabled_providers: [anthropic, copilot, azure_ai, aws_cur]}'")
