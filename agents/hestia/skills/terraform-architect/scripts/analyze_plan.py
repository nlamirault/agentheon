#!/usr/bin/env python3
"""
analyze_plan.py — Analyze terraform plan JSON output for risky operations.

Reads the JSON output of `terraform show -json tfplan` and produces a risk
report highlighting deletions, replacements, and large-scale changes that
warrant extra review before applying.

Usage:
  terraform plan -out=tfplan && terraform show -json tfplan | python3 analyze_plan.py
  python3 analyze_plan.py plan.json
  python3 analyze_plan.py -   (reads stdin)
"""

import json
import sys
from pathlib import Path
from collections import defaultdict

# Resources whose deletion or replacement should always be flagged as high risk
HIGH_RISK_RESOURCE_TYPES = {
    # Databases
    "aws_db_instance", "aws_rds_cluster", "aws_rds_cluster_instance",
    "azurerm_postgresql_server", "azurerm_mysql_server", "azurerm_sql_server",
    "google_sql_database_instance",
    # Object storage
    "aws_s3_bucket", "azurerm_storage_account", "google_storage_bucket",
    # Stateful compute
    "aws_instance", "aws_autoscaling_group",
    "azurerm_virtual_machine", "azurerm_virtual_machine_scale_set",
    "google_compute_instance",
    # Networking
    "aws_vpc", "aws_subnet", "aws_route_table",
    "azurerm_virtual_network", "azurerm_subnet",
    "google_compute_network", "google_compute_subnetwork",
    # IAM
    "aws_iam_role", "aws_iam_policy",
    "azurerm_role_assignment",
    "google_project_iam_binding", "google_project_iam_member",
    # Secrets
    "aws_secretsmanager_secret", "azurerm_key_vault_secret",
    "google_secret_manager_secret",
    # Kubernetes
    "kubernetes_namespace", "kubernetes_persistent_volume_claim",
}


def parse_plan(data: dict) -> dict:
    """Extract changes from terraform show -json output."""
    result = {
        "format_version": data.get("format_version"),
        "changes": [],
        "outputs": [],
    }

    resource_changes = data.get("resource_changes", [])
    for rc in resource_changes:
        change = rc.get("change", {})
        actions = change.get("actions", [])
        if actions == ["no-op"] or actions == ["read"]:
            continue

        resource_type = rc.get("type", "")
        resource_name = rc.get("address", rc.get("name", ""))
        is_high_risk = resource_type in HIGH_RISK_RESOURCE_TYPES

        result["changes"].append({
            "address": resource_name,
            "type": resource_type,
            "actions": actions,
            "is_high_risk_type": is_high_risk,
            "before": change.get("before"),
            "after": change.get("after"),
        })

    output_changes = data.get("output_changes", {})
    for name, oc in output_changes.items():
        actions = oc.get("actions", [])
        if actions != ["no-op"]:
            result["outputs"].append({"name": name, "actions": actions})

    return result


def classify_risk(changes: list) -> dict:
    by_action = defaultdict(list)
    high_risk = []

    for c in changes:
        actions = tuple(sorted(c["actions"]))
        if "delete" in c["actions"] and "create" not in c["actions"]:
            by_action["delete"].append(c)
        elif "delete" in c["actions"] and "create" in c["actions"]:
            by_action["replace"].append(c)
        elif "create" in c["actions"]:
            by_action["create"].append(c)
        elif "update" in c["actions"]:
            by_action["update"].append(c)

        if c["is_high_risk_type"] and ("delete" in c["actions"] or "replace" in c["actions"]):
            high_risk.append(c)

    return {"by_action": dict(by_action), "high_risk": high_risk}


def risk_level(classification: dict, total: int) -> str:
    deletes = len(classification["by_action"].get("delete", []))
    replaces = len(classification["by_action"].get("replace", []))
    high_risk = len(classification["high_risk"])

    if high_risk > 0:
        return "HIGH"
    if deletes > 0 or replaces > 0:
        return "MEDIUM"
    if total > 50:
        return "MEDIUM"
    return "LOW"


def print_report(parsed: dict) -> None:
    changes = parsed["changes"]
    classification = classify_risk(changes)
    total = len(changes)
    level = risk_level(classification, total)

    risk_emoji = {"HIGH": "🔴", "MEDIUM": "⚠️", "LOW": "✅"}
    print(f"\n{'='*55}")
    print(f"  Terraform Plan Risk Analysis")
    print(f"{'='*55}")
    print(f"  Risk Level: {risk_emoji[level]} {level}")
    print(f"  Total changes: {total}")

    by_action = classification["by_action"]
    counts = {
        "create": len(by_action.get("create", [])),
        "update": len(by_action.get("update", [])),
        "replace": len(by_action.get("replace", [])),
        "delete": len(by_action.get("delete", [])),
    }
    print(f"  ➕ Create: {counts['create']}  ✏️ Update: {counts['update']}  "
          f"🔄 Replace: {counts['replace']}  🗑️ Delete: {counts['delete']}")
    print()

    # High-risk resources
    if classification["high_risk"]:
        print(f"🔴 HIGH-RISK OPERATIONS ({len(classification['high_risk'])})")
        print("   These resource types are stateful or critical — verify before applying:\n")
        for c in classification["high_risk"]:
            action_str = " + ".join(c["actions"]).upper()
            print(f"   [{action_str}] {c['address']}  (type: {c['type']})")
        print()

    # All deletions
    deletes = by_action.get("delete", [])
    if deletes:
        print(f"🗑️  DELETIONS ({len(deletes)})")
        for c in deletes:
            marker = " ← HIGH RISK" if c["is_high_risk_type"] else ""
            print(f"   {c['address']}{marker}")
        print()

    # All replacements (destroy + create)
    replaces = by_action.get("replace", [])
    if replaces:
        print(f"🔄 REPLACEMENTS — destroy then recreate ({len(replaces)})")
        print("   Replacements cause downtime for stateful resources:\n")
        for c in replaces:
            marker = " ← HIGH RISK" if c["is_high_risk_type"] else ""
            print(f"   {c['address']}{marker}")
        print()

    # Output changes
    if parsed["outputs"]:
        print(f"📤 OUTPUT CHANGES ({len(parsed['outputs'])})")
        for o in parsed["outputs"]:
            print(f"   {o['name']}: {' + '.join(o['actions'])}")
        print()

    print(f"{'─'*55}")
    if level == "HIGH":
        print("⛔ HIGH RISK: Review all flagged resources carefully.")
        print("   Confirm with the team before running terraform apply.")
    elif level == "MEDIUM":
        print("⚠️  MEDIUM RISK: Deletions or replacements detected.")
        print("   Confirm intended behavior before applying.")
    else:
        print("✅ LOW RISK: No destructive changes detected.")
    print()

    return level == "HIGH"


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] == "-":
        raw = sys.stdin.read()
    else:
        raw = Path(sys.argv[1]).read_text(encoding="utf-8")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"Error: Could not parse plan JSON: {e}", file=sys.stderr)
        print("Make sure to use: terraform show -json tfplan", file=sys.stderr)
        sys.exit(1)

    parsed = parse_plan(data)
    is_high_risk = print_report(parsed)
    sys.exit(2 if is_high_risk else 0)


if __name__ == "__main__":
    main()
