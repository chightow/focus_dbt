#!/usr/bin/env python3
"""
Generate a complete dbt-duckdb project from a FOCUS model JSON file.

Usage:
    python generate_dbt_project.py --version 1.4
    python generate_dbt_project.py --version 1.4 --dataset CostAndUsage
    python generate_dbt_project.py --local path/to/model-1.4.json
"""

import argparse
import json
import logging
import os
import re
import sys
from collections import defaultdict
from typing import Any, Dict, List, Optional, Set, Tuple

import requests

log = logging.getLogger("focus_dbt_gen")

GITHUB_OWNER = "FinOps-Open-Cost-and-Usage-Spec"
GITHUB_REPO = "FOCUS_Spec"

RULES_DIR = os.path.join(
    os.path.dirname(__file__), "..", "focus_validator", "focus_validator", "rules"
)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "focus_dbt_project")

DBT_PROJECT_NAME = "focus_validator_dbt"

FRAMEWORK_FILES_DIR = os.path.join(os.path.dirname(__file__), "focus_dbt_project")

FOCUS_TO_DBT_TEST = {
    "ColumnPresent": None,
    "TypeString": "focus_type_string",
    "TypeDecimal": "focus_type_decimal",
    "TypeDateTime": "focus_type_datetime",
    "TypeJSON": "focus_type_json",
    "FormatString": "focus_format_string",
    "FormatNumeric": "focus_format_numeric",
    "FormatDateTime": "focus_format_datetime",
    "FormatCurrency": "focus_format_currency",
    "FormatUnit": "focus_format_unit",
    "FormatKeyValue": "focus_format_key_value",
    "FormatJSON": "focus_format_json",
    "CheckValue": None,
    "CheckNotValue": None,
    "CheckNull": None,
    "CheckRegexMatch": "focus_regex_match",
    "CheckNationalCurrency": "focus_national_currency",
    "CheckGreaterOrEqualThanValue": "focus_greater_or_equal",
    "CheckLessOrEqualThanValue": "focus_less_or_equal",
    "CheckNoDuplicates": "unique",
    "CheckSameValue": "focus_column_equality",
    "CheckDecimalValue": "focus_decimal_value",
    "ColumnByColumnEqualsColumnValue": "focus_multiplication_equals",
    "CheckStringEndsWith": "focus_string_ends_with",
    "CheckDistinctCount": "focus_distinct_count",
    "CheckColumnComparison": "focus_column_comparison",
}

CURRENCY_CODES = [
    "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN",
    "BAM", "BBD", "BDT", "BGN", "BHD", "BIF", "BMD", "BND", "BOB", "BOV",
    "BRL", "BSD", "BTN", "BWP", "BYN", "BZD", "CAD", "CDF", "CHE", "CHF",
    "CHW", "CLF", "CLP", "CNY", "COP", "COU", "CRC", "CUC", "CUP", "CVE",
    "CZK", "DJF", "DKK", "DOP", "DZD", "EGP", "ERN", "ETB", "EUR", "FJD",
    "FKP", "GBP", "GEL", "GHS", "GIP", "GMD", "GNF", "GTQ", "GYD", "HKD",
    "HNL", "HTG", "HUF", "IDR", "ILS", "INR", "IQD", "IRR", "ISK", "JMD",
    "JOD", "JPY", "KES", "KGS", "KHR", "KMF", "KPW", "KRW", "KWD", "KYD",
    "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "LYD", "MAD", "MDL", "MGA",
    "MKD", "MMK", "MNT", "MOP", "MRU", "MUR", "MVR", "MWK", "MXN", "MXV",
    "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR", "NZD", "OMR", "PAB",
    "PEN", "PGK", "PHP", "PKR", "PLN", "PYG", "QAR", "RON", "RSD", "RUB",
    "RWF", "SAR", "SBD", "SCR", "SDG", "SEK", "SGD", "SHP", "SLE", "SLL",
    "SOS", "SRD", "SSP", "STN", "SVC", "SYP", "SZL", "THB", "TJS", "TMT",
    "TND", "TOP", "TRY", "TTD", "TWD", "TZS", "UAH", "UGX", "USD", "USN",
    "UYI", "UYU", "UYW", "UZS", "VED", "VES", "VND", "VUV", "WST", "XAF",
    "XAG", "XAU", "XBA", "XBB", "XBC", "XBD", "XCD", "XDR", "XOF", "XPD",
    "XPF", "XPT", "XSU", "XTS", "XUA", "XXX", "YER", "ZAR", "ZMW", "ZWG",
]


def find_release_assets(
    owner: str = GITHUB_OWNER,
    repo: str = GITHUB_REPO,
    per_page: int = 100,
    timeout: float = 15.0,
) -> Dict[str, Dict[str, Any]]:
    """Scan GitHub releases for model JSON files (mirrors spec_rules.py)."""
    session = requests.Session()
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "focus-dbt-gen/asset-scan",
    }
    results: Dict[str, Dict[str, Any]] = {}
    page = 1
    while True:
        url = f"https://api.github.com/repos/{owner}/{repo}/releases"
        resp = session.get(url, headers=headers, params={"per_page": per_page, "page": page}, timeout=timeout)
        if resp.status_code == 404:
            raise ValueError(f"Repo not found: {owner}/{repo}")
        if resp.status_code == 401:
            raise PermissionError("Unauthorized")
        if resp.status_code == 403:
            raise RuntimeError(f"Forbidden / rate limited: {resp.text}")
        resp.raise_for_status()
        releases = resp.json()
        if not releases:
            break
        for rel in releases:
            release_tag = rel.get("tag_name", "")
            for asset in rel.get("assets", []) or []:
                filename = asset.get("name", "")
                if not (filename.startswith("model-") and filename.endswith(".json")):
                    continue
                model_version = filename[len("model-"):-len(".json")]
                if model_version and model_version not in results:
                    results[model_version] = {
                        "release_tag": release_tag,
                        "filename": filename,
                        "asset_browser_download_url": asset.get("browser_download_url"),
                    }
        page += 1
    return results


def download_model(version: str, dest_dir: str) -> str:
    """Download a model JSON file, returns local path."""
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, f"model-{version}.json")
    if os.path.exists(dest_path):
        log.info("Using cached %s", dest_path)
        return dest_path
    log.info("Scanning GitHub releases for version %s...", version)
    assets = find_release_assets()
    if version not in assets:
        matches = [k for k in assets if k.startswith(version + ".") or k == version]
        if not matches:
            raise ValueError(f"Version {version} not found. Available: {sorted(assets.keys())}")
        matches.sort(key=lambda v: tuple(int(x) for x in v.split(".")), reverse=True)
        version = matches[0]
        log.info("Matched to %s", version)
    url = assets[version]["asset_browser_download_url"]
    log.info("Downloading %s ...", url)
    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    with open(dest_path, "wb") as f:
        f.write(resp.content)
    log.info("Saved to %s", dest_path)
    return dest_path


def load_model(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _extract_leaf_checks(requirement: dict) -> List[dict]:
    """Recursively extract leaf check definitions from a requirement tree."""
    leaves = []
    cf = requirement.get("CheckFunction", "")
    if cf in ("AND", "OR"):
        for item in requirement.get("Items", []):
            leaves.extend(_extract_leaf_checks(item))
    elif cf == "CheckModelRule":
        pass
    else:
        leaf = dict(requirement)
        leaf["_function"] = cf
        leaves.append(leaf)
    return leaves


def _parse_rule_id_parts(rule_id: str) -> dict:
    """Parse e.g. CAU-RegionId-C-001-M into dataset, column, etc."""
    parts = rule_id.split("-", 1)
    dataset_prefix = parts[0] if len(parts) > 1 else ""
    rest = parts[1] if len(parts) > 1 else rule_id
    return {"dataset_prefix": dataset_prefix, "rest": rest}


DATASET_PREFIX_MAP = {
    "CAU": "CostAndUsage",
    "IND": "InvoiceDetail",
    "BIP": "BillingPeriod",
    "CCT": "ContractCommitment",
}


def extract_columns_and_checks(model: dict) -> Dict[str, Dict[str, List[dict]]]:
    """
    Parse model rules and return:
        dataset_name -> { column_name -> [leaf_check_defs] }
    Also collects source and model info per dataset.
    """
    rules = model.get("ModelRules", {})
    datasets = model.get("ModelDatasets", {})

    # Build dataset -> column -> checks
    result: Dict[str, Dict[str, List[dict]]] = {}
    # Track column types from TypeString/TypeDecimal checks
    column_types: Dict[str, str] = {}

    for rule_id, rule in rules.items():
        status = rule.get("Status", "")
        if status in ("Removed", "Deprecated"):
            continue
        entity_type = rule.get("EntityType", "")
        if entity_type != "Column":
            continue

        dataset_id = rule.get("DatasetId", "")
        dataset_name = rule.get("DatasetName", dataset_id)
        if dataset_name not in result:
            result[dataset_name] = defaultdict(list)

        column_name = rule.get("Reference") or rule.get("EntityId", "")
        if not column_name:
            continue

        vc = rule.get("ValidationCriteria", {})
        requirement = vc.get("Requirement", {})
        condition = vc.get("Condition", {})
        keyword = vc.get("Keyword", "MUST")
        must_satisfy = vc.get("MustSatisfy", "")
        applicability = rule.get("ApplicabilityCriteria", [])
        rule_function = rule.get("Function", "")
        rule_type = rule.get("Type", "")

        if not requirement:
            continue

        if requirement.get("CheckFunction") in ("AND", "OR"):
            leaf_checks = _extract_leaf_checks(requirement)
        else:
            leaf_checks = [dict(requirement)]
            leaf_checks[0]["_function"] = requirement.get("CheckFunction", "")

        for lc in leaf_checks:
            lc["_rule_id"] = rule_id
            lc["_keyword"] = keyword
            lc["_must_satisfy"] = must_satisfy
            lc["_condition"] = condition
            lc["_applicability"] = applicability
            lc["_rule_function"] = rule_function
            lc["_rule_type"] = rule_type
            result[dataset_name][column_name].append(lc)

        if rule_function == "Type":
            cf = requirement.get("CheckFunction", "")
            if cf == "TypeString":
                column_types[column_name] = "VARCHAR"
            elif cf == "TypeDecimal":
                column_types[column_name] = "DOUBLE"

    # Also collect column presence rules to know ALL columns
    for rule_id, rule in rules.items():
        status = rule.get("Status", "")
        if status in ("Removed", "Deprecated"):
            continue
        if rule.get("EntityType") != "Column":
            continue
        dataset_name = rule.get("DatasetName", "")
        column_name = rule.get("Reference") or rule.get("EntityId", "")
        if not column_name or dataset_name not in result:
            continue
        vc = rule.get("ValidationCriteria", {})
        requirement = vc.get("Requirement", {})
        if requirement.get("CheckFunction") == "ColumnPresent":
            if column_name not in result[dataset_name]:
                result[dataset_name][column_name] = []
            result[dataset_name][column_name].append({
                "_rule_id": rule_id,
                "_function": "ColumnPresent",
                "_keyword": vc.get("Keyword", "MUST"),
                "_must_satisfy": vc.get("MustSatisfy", ""),
                "_condition": {},
                "_applicability": rule.get("ApplicabilityCriteria", []),
                "_rule_function": "Presence",
                "_rule_type": rule.get("Type", ""),
            })

    return result, column_types


def _get_check_value_pairs(check: dict) -> List[Tuple[str, Any]]:
    """Get (column_name, value) pairs from a check dict."""
    pairs = []
    if "ColumnName" in check and "Value" in check:
        pairs.append((check["ColumnName"], check["Value"]))
    if "ColumnAName" in check and "ColumnBName" in check:
        pairs.append((check["ColumnAName"], check["ColumnBName"]))
    if "ResultColumnName" in check:
        pairs.append(("Result", check["ResultColumnName"]))
    return pairs


def _encode_value(v: Any) -> str:
    """Encode a value for use in dbt test name."""
    if v is None:
        return "null"
    if isinstance(v, bool):
        return str(v).lower()
    return str(v).replace(" ", "_").replace("-", "_")


def _test_name_from_rule(check: dict) -> str:
    """Generate a dbt test name from a FOCUS rule check."""
    cf = check.get("_function", "unknown")
    rule_id = check.get("_rule_id", "unknown")
    short_id = rule_id.split("-")[-1] if "-" in rule_id else rule_id
    return f"{cf.lower()}_{short_id}"


def _build_generic_test(check: dict) -> Optional[dict]:
    """Map a FOCUS leaf check to a dbt generic test config."""
    cf = check.get("_function", "")
    dbt_test = FOCUS_TO_DBT_TEST.get(cf)
    if dbt_test is None:
        return None

    test_config: dict = {}
    config: dict = {}
    where_clauses = []

    severity = "error" if check.get("_keyword") in ("MUST", "MUST NOT") else "warn"
    config["severity"] = severity
    config["tags"] = ["focus", cf.lower()]

    if check.get("_applicability"):
        config["tags"].append("conditional")

    condition = check.get("_condition", {})
    if condition and condition.get("CheckFunction") in ("AND", "OR", "CheckValue", "CheckNotValue"):
        config["tags"].append("conditional")

    test_config["config"] = config

    if dbt_test == "unique":
        return {"unique": test_config}

    if dbt_test == "focus_type_string":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_type_decimal":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_type_datetime":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_type_json":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_string":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_numeric":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_datetime":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_currency":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_unit":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_key_value":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_format_json":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_regex_match":
        test_config["column_name"] = check.get("ColumnName", "")
        test_config["pattern"] = check.get("Pattern", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_national_currency":
        test_config["column_name"] = check.get("ColumnName", "")
        test_config["values"] = CURRENCY_CODES
        return {dbt_test: test_config}

    if dbt_test == "focus_greater_or_equal":
        test_config["column_name"] = check.get("ColumnName", "")
        test_config["threshold"] = check.get("Value", 0)
        return {dbt_test: test_config}

    if dbt_test == "focus_less_or_equal":
        test_config["column_name"] = check.get("ColumnName", "")
        test_config["threshold"] = check.get("Value", 0)
        return {dbt_test: test_config}

    if dbt_test == "focus_decimal_value":
        test_config["column_name"] = check.get("ColumnName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_column_equality":
        test_config["column_a"] = check.get("ColumnAName", "")
        test_config["column_b"] = check.get("ColumnBName", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_multiplication_equals":
        test_config["column_a"] = check.get("ColumnAName", "")
        test_config["column_b"] = check.get("ColumnBName", "")
        test_config["result_column"] = check.get("ResultColumnName", "")
        test_config["tolerance"] = 0.01
        return {dbt_test: test_config}

    if dbt_test == "focus_string_ends_with":
        test_config["column_name"] = check.get("ColumnName", "")
        test_config["value"] = check.get("Value", "")
        return {dbt_test: test_config}

    if dbt_test == "focus_distinct_count":
        test_config["column_a"] = check.get("ColumnAName", "")
        test_config["column_b"] = check.get("ColumnBName", "")
        test_config["expected_count"] = check.get("ExpectedCount", 0)
        return {dbt_test: test_config}

    if dbt_test == "focus_column_comparison":
        test_config["column_a"] = check.get("ColumnAName", "")
        test_config["column_b"] = check.get("ColumnBName", "")
        test_config["comparator"] = check.get("Comparator", "")
        return {dbt_test: test_config}

    return None


def _build_accepted_values_test(check: dict) -> Optional[dict]:
    """Build accepted_values test from CheckValue rules with literal values."""
    cf = check.get("_function", "")
    if cf != "CheckValue":
        return None
    col = check.get("ColumnName", "")
    val = check.get("Value")
    if val is None:
        return None
    if not isinstance(val, (str, int, float, bool)):
        return None

    config = {
        "severity": "error" if check.get("_keyword") in ("MUST", "MUST NOT") else "warn",
        "tags": ["focus", "check_value"],
    }
    if check.get("_applicability"):
        config["tags"].append("conditional")

    return {
        "accepted_values": {
            "config": config,
            "values": [val],
        }
    }


def _duckdb_type_for_focus(focus_function: str) -> str:
    return {
        "TypeString": "VARCHAR",
        "TypeDecimal": "DOUBLE",
        "TypeDateTime": "TIMESTAMP",
        "TypeJSON": "JSON",
    }.get(focus_function, "VARCHAR")


def _write_framework_file(src_rel_path: str, dst_rel_path: str) -> bool:
    """Copy a framework file from the existing project if it exists."""
    src = os.path.join(FRAMEWORK_FILES_DIR, src_rel_path)
    dst = os.path.join(OUTPUT_DIR, dst_rel_path)
    if os.path.exists(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(src, "r") as sf:
            content = sf.read()
        with open(dst, "w") as df:
            df.write(content)
        return True
    return False


def _generate_validate_schema(
    model: dict,
    datasets: dict,
    columns_by_dataset: dict,
    column_types: dict,
    output_path: str,
):
    """Generate validate/schema.yml with full FOCUS validation tests."""
    schema_yml_lines = ["version: 2", "", "models:"]

    model_name_map = {
        "CostAndUsage": "focus_cost_and_usage",
        "BillingPeriod": "focus_billing_period",
        "InvoiceDetail": "focus_invoice_detail",
        "ContractCommitment": "focus_contract_commitment",
    }

    for ds_name in datasets.keys():
        model_name = model_name_map.get(ds_name, f"focus_{ds_name.lower()}")
        ds_cols = columns_by_dataset.get(ds_name.replace(" ", ""), {})
        ds_rules = datasets[ds_name].get("ModelRules", [])
        all_cols_in_ds = set(ds_cols.keys())
        for rule_id in ds_rules:
            rule = model.get("ModelRules", {}).get(rule_id, {})
            ref = rule.get("Reference", rule.get("EntityId", ""))
            if ref:
                all_cols_in_ds.add(ref)

        schema_yml_lines.append(f"  - name: {model_name}")
        schema_yml_lines.append(f"    description: \"FOCUS {ds_name} dataset validation model\"")
        schema_yml_lines.append(f"    columns:")

        for col_name in sorted(all_cols_in_ds):
            col_type = column_types.get(col_name, "VARCHAR")
            schema_yml_lines.append(f"      - name: {col_name}")
            schema_yml_lines.append(f"        data_type: {col_type}")
            schema_yml_lines.append(f"        description: \"FOCUS {col_name} column\"")

            tests_for_col = []
            checks = ds_cols.get(col_name, [])

            # Add ColumnPresent -> not_null test
            column_present = any(c.get("_function") == "ColumnPresent" for c in checks)
            if column_present:
                keyword = "error"
                for c in checks:
                    if c.get("_function") == "ColumnPresent":
                        kw = c.get("_keyword", "MUST")
                        if kw == "SHOULD":
                            keyword = "warn"
                        break
                tests_for_col.append({
                    "not_null": {
                        "config": {
                            "severity": keyword,
                            "tags": ["focus", "presence", ds_name.lower()]
                        }
                    }
                })

            for check in checks:
                generic_test = _build_generic_test(check)
                if generic_test:
                    tests_for_col.append(generic_test)
                accepted = _build_accepted_values_test(check)
                if accepted:
                    existing_av = next((t for t in tests_for_col if "accepted_values" in t), None)
                    if existing_av:
                        existing_val = existing_av["accepted_values"].get("values", [])
                        new_val = accepted["accepted_values"].get("values", [])
                        if new_val and new_val[0] not in existing_val:
                            existing_val.append(new_val[0])
                    else:
                        tests_for_col.append(accepted)

            if tests_for_col:
                schema_yml_lines.append(f"        tests:")
                for test in tests_for_col:
                    for test_name, test_cfg in test.items():
                        schema_yml_lines.append(f"          - {test_name}:")
                        for k, v in test_cfg.items():
                            if k == "config":
                                schema_yml_lines.append(f"              config:")
                                for ck, cv in v.items():
                                    if isinstance(cv, list):
                                        cv_str = ", ".join(f'"{x}"' for x in cv)
                                        schema_yml_lines.append(f"                {ck}: [{cv_str}]")
                                    elif isinstance(cv, str):
                                        schema_yml_lines.append(f"                {ck}: {cv}")
                                    else:
                                        schema_yml_lines.append(f"                {ck}: {cv}")
                            elif k == "values" and isinstance(v, list):
                                v_str = ", ".join(f'"{x}"' for x in v)
                                schema_yml_lines.append(f"              {k}: [{v_str}]")
                            elif isinstance(v, str):
                                schema_yml_lines.append(f"              {k}: \"{v}\"")
                            else:
                                schema_yml_lines.append(f"              {k}: {v}")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        f.write("\n".join(schema_yml_lines) + "\n")


def generate_dbt_project(model: dict, focus_version: str):
    """Generate complete layered dbt project with DuckDB native ingestion."""
    details = model.get("Details", {})
    focus_version = details.get("FOCUSVersion", focus_version)
    model_version = details.get("ModelVersion", focus_version)

    columns_by_dataset, column_types = extract_columns_and_checks(model)
    datasets = model.get("ModelDatasets", {})
    applicability = model.get("ApplicabilityCriteria", {})

    # Create all directories
    subdirs = [
        "models/staging", "models/intermediate/providers/aws",
        "models/intermediate/providers/azure", "models/intermediate/providers/gcp",
        "models/focus", "models/validate",
        "macros/ingest", "macros/map",
        "tests", "seeds", "examples", "data",
    ]
    for sd in subdirs:
        os.makedirs(os.path.join(OUTPUT_DIR, sd), exist_ok=True)

    #
    # dbt_project.yml - layered config
    #
    dbt_project_yml = f"""name: '{DBT_PROJECT_NAME}'
version: '{focus_version}'
config-version: 2
profile: '{DBT_PROJECT_NAME}'

model-paths: ["models"]
macro-paths: ["macros"]
test-paths: ["tests"]
seed-paths: ["seeds"]
snapshot-paths: ["snapshots"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  {DBT_PROJECT_NAME}:
    +database: focus
    +schema: main

    staging:
      +materialized: view
      +tags: ["staging"]

    intermediate:
      +materialized: view
      +tags: ["intermediate"]
      providers:
        +materialized: view

    focus:
      +materialized: view
      +tags: ["focus", "canonical"]

    validate:
      +materialized: view
      +tags: ["validate", "focus"]

vars:
  focus_version: "{focus_version}"
  focus_model_version: "{model_version}"
  provider: "none"
  cau_csv_path: "data/cost_and_usage.csv"
  bip_csv_path: "data/billing_period.csv"
  cct_csv_path: "data/contract_commitment.csv"
  ind_csv_path: "data/invoice_detail.csv"

dispatch:
  - macro_namespace: {DBT_PROJECT_NAME}
    search_order: ["{DBT_PROJECT_NAME}"]
"""
    with open(os.path.join(OUTPUT_DIR, "dbt_project.yml"), "w") as f:
        f.write(dbt_project_yml)

    #
    # packages.yml
    #
    with open(os.path.join(OUTPUT_DIR, "packages.yml"), "w") as f:
        f.write("""packages:
  - package: dbt-labs/dbt_utils
    version: ">=1.3.0"
""")

    #
    # profiles.yml
    #
    with open(os.path.join(OUTPUT_DIR, "profiles.yml"), "w") as f:
        f.write(f"""{DBT_PROJECT_NAME}:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: focus_{focus_version.replace('.', '_')}.duckdb
      threads: 4
""")

    #
    # models/sources.yml - comprehensive column definitions
    #
    sources_yml_lines = ["version: 2", "", "sources:"]
    sources_yml_lines.extend([
        '  - name: raw_provider_data',
        '    database: focus',
        '    schema: main',
        '    description: "Raw provider billing data files ingested via DuckDB native readers"',
        '    freshness:',
        '      warn_after:',
        '        count: 24',
        '        period: hour',
        '    loaded_at_field: _loaded_at',
        '    tables:',
    ])
    for ds_name in datasets.keys():
        safe = ds_name[0].lower() + ds_name[1:]
        sources_yml_lines.append(f'      - name: {safe}')
        sources_yml_lines.append(f'        description: "Raw {ds_name} data (CSV/Parquet/JSON)"')
        sources_yml_lines.append(f'        external:')
        sources_yml_lines.append(f"          location: \"{{{{ var('{safe}_csv_path', 'data/{safe}.csv') }}}}\"")
        sources_yml_lines.append('          options:')
        sources_yml_lines.append(f"            format: \"{{{{ var('{safe}_format', 'csv') }}}}\"")
        sources_yml_lines.append('        columns:')
        sources_yml_lines.append('          - name: _raw_content')
        sources_yml_lines.append('            data_type: VARCHAR')
        sources_yml_lines.append('            description: "Raw file contents"')

    # Build canonical FOCUS sources
    sources_yml_lines.extend([
        '  - name: focus_datasets',
        '    database: focus',
        '    schema: main',
        '    description: "Canonical FOCUS output datasets"',
        '    tables:',
    ])
    for ds_name in datasets.keys():
        ds_cols = columns_by_dataset.get(ds_name.replace(" ", ""), {})
        all_cols = set()
        for rule_id in datasets[ds_name].get("ModelRules", []):
            rule = model.get("ModelRules", {}).get(rule_id, {})
            ref = rule.get("Reference", rule.get("EntityId", ""))
            if ref:
                all_cols.add(ref)
        all_cols.update(ds_cols.keys())
        sources_yml_lines.append(f'      - name: {ds_name}')
        sources_yml_lines.append(f'        description: "FOCUS {ds_name} dataset"')
        sources_yml_lines.append('        columns:')
        for col_name in sorted(all_cols):
            ct = column_types.get(col_name, "VARCHAR")
            sources_yml_lines.append(f'          - name: {col_name}')
            sources_yml_lines.append(f'            data_type: {ct}')

    with open(os.path.join(OUTPUT_DIR, "models", "sources.yml"), "w") as f:
        f.write("\n".join(sources_yml_lines) + "\n")

    #
    # Generate validate/schema.yml with FOCUS tests (the core generated content)
    #
    _generate_validate_schema(
        model, datasets, columns_by_dataset, column_types,
        os.path.join(OUTPUT_DIR, "models", "validate", "schema.yml"),
    )

    #
    # macros/focus_tests.sql - custom generic tests (unchanged)
    #
    macros_sql = """{% macro focus_test_config(severity='error', tags=[]) %}
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
    AND {{ column_name }}::VARCHAR !~ '^-?\\d+(\\.\\d+)?$'
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
"""
    with open(os.path.join(OUTPUT_DIR, "macros", "focus_tests.sql"), "w") as f:
        f.write(macros_sql)

    #
    # seeds - currency codes
    #
    with open(os.path.join(OUTPUT_DIR, "seeds", "currency_codes.csv"), "w") as f:
        f.write("currency_code\n")
        for code in CURRENCY_CODES:
            f.write(f"{code}\n")

    #
    # Framework files - write only if they don't exist (preserve user edits)
    #
    framework_files = {
        "macros/ingest/focus_ingest.sql": "macros/ingest/focus_ingest.sql",
        "macros/map/focus_map.sql": "macros/map/focus_map.sql",
        "models/staging/stg_cost_and_usage.sql": "models/staging/stg_cost_and_usage.sql",
        "models/staging/stg_billing_period.sql": "models/staging/stg_billing_period.sql",
        "models/staging/stg_contract_commitment.sql": "models/staging/stg_contract_commitment.sql",
        "models/staging/stg_invoice_detail.sql": "models/staging/stg_invoice_detail.sql",
        "models/staging/stg_anthropic_usage.sql": "models/staging/stg_anthropic_usage.sql",
        "models/staging/stg_anthropic_cost.sql": "models/staging/stg_anthropic_cost.sql",
        "models/intermediate/providers/anthropic/int_anthropic_cost_and_usage.sql": "models/intermediate/providers/anthropic/int_anthropic_cost_and_usage.sql",
        "models/focus/focus_cost_and_usage.sql": "models/focus/focus_cost_and_usage.sql",
        "models/focus/focus_billing_period.sql": "models/focus/focus_billing_period.sql",
        "models/focus/focus_invoice_detail.sql": "models/focus/focus_invoice_detail.sql",
        "models/focus/focus_contract_commitment.sql": "models/focus/focus_contract_commitment.sql",
        "models/staging/schema.yml": "models/staging/schema.yml",
        "models/intermediate/schema.yml": "models/intermediate/schema.yml",
    }
    for src_rel, dst_rel in framework_files.items():
        _write_framework_file(src_rel, dst_rel)

    #
    # Generate README
    #
    ds_list = "\n".join(f"  - {n}" for n in datasets.keys())
    readme = f"""# FOCUS v{focus_version} dbt Framework

Auto-generated from FOCUS model v{model_version}.

## Architecture

```
Provider Data (CSV/Parquet/JSON/SQLite/Postgres)
    |
    | DuckDB native readers (read_csv_auto, read_parquet, read_json_auto)
    v
┌─────────────────────────────────────┐
│  staging/  - Raw ingestion          │
│  DuckDB reads files directly        │
└─────────────────────────────────────┘
    |
    | Column mapping (provider column -> FOCUS column)
    v
┌─────────────────────────────────────┐
│  intermediate/ - Provider mapping   │
│  AWS CUR -> FOCUS                   │
│  Azure cost -> FOCUS                │
│  GCP billing -> FOCUS               │
│  Custom: add your own               │
└─────────────────────────────────────┘
    |
    v
┌─────────────────────────────────────┐
│  focus/ - Canonical FOCUS output    │
│  CostAndUsage, BillingPeriod,       │
│  InvoiceDetail, ContractCommitment  │
└─────────────────────────────────────┘
    |
    | dbt tests (FOCUS spec rules)
    v
┌─────────────────────────────────────┐
│  validate/ - FOCUS spec validation  │
│  Type checks, format checks,        │
│  range checks, cross-column checks  │
└─────────────────────────────────────┘
    |
    v
Pass/Fail Report
```

## Datasets

{ds_list}

## Quick Start

### 1. Install

```bash
pip install dbt-duckdb
```

### 2. Point at your data

Edit `dbt_project.yml` vars or pass via CLI:

```bash
dbt run --vars '{{cau_csv_path: "path/to/aws_cur.csv"}}'
```

Or set provider-specific mapping:

```bash
dbt run --vars '{{provider: "aws", cau_csv_path: "path/to/cur.csv"}}'
```

### 3. Run validation

```bash
dbt build --select tag:focus
```

### 4. Run specific dataset

```bash
dbt build --select focus_cost_and_usage
```

## Adding a New Provider

1. Create `models/intermediate/providers/<name>/int_<name>_cost_and_usage.sql`
2. Define a column mapping dict (see `int_aws_cost_and_usage.sql` for reference)
3. Use `{{{{ focus_apply_mapping('stg', your_mapping, 'CostAndUsage') }}}}`
4. Register it in `models/focus/focus_cost_and_usage.sql` UNION ALL
5. Run `dbt run --select int_<name>_cost_and_usage`

## Custom Generic Tests

The FOCUS validation tests are auto-generated from the spec:

| Category | Tests |
|----------|-------|
| Type | `focus_type_string`, `focus_type_decimal`, `focus_type_datetime`, `focus_type_json` |
| Format | `focus_format_string`, `focus_format_numeric`, `focus_format_datetime`, `focus_format_currency`, `focus_format_unit`, `focus_format_key_value`, `focus_format_json` |
| Range | `focus_greater_or_equal`, `focus_less_or_equal` |
| Cross-column | `focus_column_equality`, `focus_multiplication_equals`, `focus_column_comparison` |
| Pattern | `focus_regex_match`, `focus_string_ends_with` |
| Currency | `focus_national_currency` |
| Cardinality | `focus_distinct_count` |

## DuckDB Macros

Use the built-in ingestion macros in your own models:

```sql
-- Read any CSV with auto-schema detection
SELECT * FROM {{{{ focus_read_csv('path/to/data.csv') }}}}

-- Read Parquet (supports hive partitioning)
SELECT * FROM {{{{ focus_read_parquet('path/to/data/') }}}}

-- Read JSON
SELECT * FROM {{{{ focus_read_json('path/to/data.json') }}}}

-- Attach external databases
{{{{ focus_attach_postgres('conn_string') }}}}
SELECT * FROM ext_source.public.table_name
```

## Tags for Selective Runs

- `tag:staging` - raw ingestion models
- `tag:intermediate` - provider mapping models
- `tag:focus` - canonical FOCUS outputs
- `tag:validate` - FOCUS spec validation
- `tag:type` - type checks only
- `tag:format` - format checks only
- `tag:conditional` - conditional rules
- `tag:cross_column` - cross-column consistency
"""
    with open(os.path.join(OUTPUT_DIR, "README.md"), "w") as f:
        f.write(readme)

    # Summary stats
    total_tests = 0
    total_checks = 0
    for ds_name, ds_cols in columns_by_dataset.items():
        for col_name, checks in ds_cols.items():
            total_checks += len(checks)
            for check in checks:
                if _build_generic_test(check) or _build_accepted_values_test(check):
                    total_tests += 1

    log.info("=" * 50)
    log.info("Generated FOCUS dbt Framework: %s", OUTPUT_DIR)
    log.info("  FOCUS version: %s", focus_version)
    log.info("  Datasets: %s", list(columns_by_dataset.keys()))
    log.info("  Columns found: %d", sum(len(c) for c in columns_by_dataset.values()))
    log.info("  FOCUS rules mapped: %d", total_checks)
    log.info("  dbt tests generated: %d", total_tests)
    log.info("=" * 50)
    log.info("Architecture:")
    log.info("  staging/       - DuckDB native file ingestion")
    log.info("  intermediate/  - Provider column mappings (AWS/Azure/GCP)")
    log.info("  focus/         - Canonical FOCUS output views")
    log.info("  validate/      - FOCUS spec validation tests")
    log.info("To use:")
    log.info("  cd %s", OUTPUT_DIR)
    log.info("  dbt deps")
    log.info("  dbt build --select tag:focus")


def main():
    parser = argparse.ArgumentParser(description="Generate dbt project from FOCUS model")
    parser.add_argument("--version", default="1.4", help="FOCUS version to generate")
    parser.add_argument("--local", help="Path to local model JSON file")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    if args.local:
        model_path = args.local
    else:
        dest = os.path.join(os.path.dirname(__file__), "downloads")
        model_path = download_model(args.version, dest)

    model = load_model(model_path)
    details = model.get("Details", {})
    focus_version = details.get("FOCUSVersion", args.version)

    generate_dbt_project(model, focus_version)


if __name__ == "__main__":
    main()
