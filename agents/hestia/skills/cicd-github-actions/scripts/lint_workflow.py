#!/usr/bin/env python3
"""
lint_workflow.py — Static analysis for GitHub Actions workflow YAML files.

Checks for common security and correctness issues without running the workflow.
Complements actionlint by catching patterns actionlint misses.

Usage:
  python3 lint_workflow.py .github/workflows/ci.yml
  python3 lint_workflow.py .github/workflows/          # lint all workflows
  python3 lint_workflow.py -                           # read from stdin
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML required. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

SEVERITY = {"error": "❌", "warn": "⚠️", "info": "ℹ️"}

# Actions that handle secrets/tokens and must be pinned to SHA
SENSITIVE_ACTIONS = {
    "actions/checkout", "actions/upload-artifact", "actions/download-artifact",
    "actions/cache", "actions/setup-node", "actions/setup-python",
    "actions/setup-go", "actions/setup-java", "docker/login-action",
    "aws-actions/configure-aws-credentials", "google-github-actions/auth",
    "azure/login",
}

SHA_RE = re.compile(r"@[0-9a-f]{40}$")
TAG_RE = re.compile(r"@v\d+\.\d+\.\d+$")
LATEST_RE = re.compile(r"@(?:latest|main|master|HEAD)$")
SEMVER_MAJOR_RE = re.compile(r"@v\d+$")  # e.g. @v3 — mutable


def findings_for_step(step: dict, job_name: str, step_idx: int) -> list:
    findings = []
    uses = step.get("uses", "")
    if not uses:
        return findings

    action_base = uses.split("@")[0] if "@" in uses else uses
    label = f"job '{job_name}', step {step_idx} ({uses!r})"

    if LATEST_RE.search(uses):
        findings.append(("error", label, "Pinned to mutable ref (latest/main/master) — pin to a SHA or semver tag"))
    elif SEMVER_MAJOR_RE.search(uses):
        if action_base in SENSITIVE_ACTIONS:
            findings.append(("warn", label, f"'{action_base}' handles auth/secrets — pin to a full SHA for supply chain safety"))
        else:
            findings.append(("info", label, "Major version tag is mutable. Pin to a full SHA for reproducibility"))
    elif "@" not in uses:
        findings.append(("error", label, "No version pin — pin to a SHA or semver tag"))

    return findings


def check_permissions(workflow: dict, source: str) -> list:
    findings = []
    top_perms = workflow.get("permissions")
    if top_perms is None:
        findings.append(("warn", source, "No top-level 'permissions:' block — defaults to broad write access. Add 'permissions: read-all' and override per-job"))
    elif top_perms == "write-all":
        findings.append(("error", source, "'permissions: write-all' grants full repo write access. Use least-privilege permissions per job"))

    jobs = workflow.get("jobs", {})
    for job_name, job in jobs.items():
        job_perms = job.get("permissions")
        if job_perms == "write-all":
            findings.append(("error", f"job '{job_name}'", "'permissions: write-all' — grant only what this job needs"))
    return findings


def check_concurrency(workflow: dict, source: str) -> list:
    findings = []
    if not workflow.get("concurrency"):
        triggers = workflow.get("on", {})
        if isinstance(triggers, dict):
            relevant = {"push", "pull_request", "pull_request_target", "workflow_dispatch"}
            if any(t in triggers for t in relevant):
                findings.append(("warn", source,
                    "No 'concurrency:' group — multiple concurrent runs possible on the same branch. "
                    "Add: concurrency: { group: '${{ github.workflow }}-${{ github.ref }}', cancel-in-progress: true }"))
    return findings


def check_pull_request_target(workflow: dict, source: str) -> list:
    findings = []
    triggers = workflow.get("on", {})
    if "pull_request_target" not in (triggers if isinstance(triggers, dict) else {}):
        return findings

    jobs = workflow.get("jobs", {})
    for job_name, job in jobs.items():
        steps = job.get("steps", [])
        uses_checkout = any(
            "actions/checkout" in s.get("uses", "") for s in steps
            if isinstance(s, dict)
        )
        if uses_checkout:
            findings.append(("error", f"job '{job_name}'",
                "SECURITY: 'pull_request_target' + 'actions/checkout' of PR code gives untrusted code access to secrets. "
                "See: https://securitylab.github.com/research/github-actions-preventing-pwn-requests/"))
    return findings


def check_hardcoded_secrets(workflow_text: str, source: str) -> list:
    findings = []
    # Look for obvious hardcoded credential patterns (not inside ${{ secrets.* }})
    patterns = [
        (r'(?i)(password|passwd|pwd|secret|token|api_key|apikey)\s*[:=]\s*["\']?[A-Za-z0-9+/]{16,}', "Possible hardcoded credential"),
        (r'ghp_[A-Za-z0-9]{36}', "GitHub Personal Access Token (ghp_*)"),
        (r'AKIA[0-9A-Z]{16}', "AWS Access Key ID pattern"),
    ]
    for pattern, label in patterns:
        for m in re.finditer(pattern, workflow_text):
            # Skip if it's inside a ${{ secrets.* }} expression
            context = workflow_text[max(0, m.start()-20):m.end()+20]
            if "secrets." not in context:
                findings.append(("error", source, f"{label} detected: '{m.group()[:40]}...' — use ${{{{ secrets.* }}}} instead"))
    return findings


def check_set_output(workflow_text: str, source: str) -> list:
    if "set-output" in workflow_text:
        return [("warn", source, "Deprecated '::set-output::' command found. Replace with: echo \"name=value\" >> $GITHUB_OUTPUT")]
    return []


def check_fail_fast(workflow: dict, source: str) -> list:
    findings = []
    jobs = workflow.get("jobs", {})
    for job_name, job in jobs.items():
        strategy = job.get("strategy", {})
        matrix = strategy.get("matrix")
        if matrix and strategy.get("fail-fast") is None:
            findings.append(("info", f"job '{job_name}'",
                "Matrix build with default fail-fast=true — if you need all matrix results, set 'fail-fast: false'"))
    return findings


def lint_file(filepath: Path) -> list:
    text = filepath.read_text(encoding="utf-8")
    try:
        workflow = yaml.safe_load(text)
    except yaml.YAMLError as e:
        return [("error", str(filepath), f"YAML parse error: {e}")]

    if not isinstance(workflow, dict):
        return []

    source = str(filepath)
    findings = []
    findings += check_permissions(workflow, source)
    findings += check_concurrency(workflow, source)
    findings += check_pull_request_target(workflow, source)
    findings += check_hardcoded_secrets(text, source)
    findings += check_set_output(text, source)
    findings += check_fail_fast(workflow, source)

    jobs = workflow.get("jobs", {})
    for job_name, job in (jobs or {}).items():
        for idx, step in enumerate(job.get("steps", []) or []):
            if isinstance(step, dict):
                findings += findings_for_step(step, job_name, idx)

    return findings


def print_report(all_findings: list) -> None:
    if not all_findings:
        print("✅ No issues found.")
        return

    by_sev = {"error": [], "warn": [], "info": []}
    for sev, loc, msg in all_findings:
        by_sev.get(sev, by_sev["info"]).append((loc, msg))

    for sev in ("error", "warn", "info"):
        items = by_sev[sev]
        if not items:
            continue
        print(f"\n{SEVERITY[sev]} {sev.upper()}S ({len(items)})")
        for loc, msg in items:
            print(f"  {loc}")
            print(f"    → {msg}")

    errors = len(by_sev["error"])
    print(f"\n{'─'*55}")
    print(f"Summary: {errors} error(s), {len(by_sev['warn'])} warning(s), {len(by_sev['info'])} info")
    sys.exit(1 if errors else 0)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] == "-":
        import tempfile
        tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".yml", delete=False)
        tmp.write(sys.stdin.read())
        tmp.close()
        paths = [Path(tmp.name)]
    else:
        target = Path(sys.argv[1])
        if target.is_dir():
            paths = sorted(target.rglob("*.yml")) + sorted(target.rglob("*.yaml"))
        else:
            paths = [target]

    all_findings = []
    for p in paths:
        all_findings += lint_file(p)

    print_report(all_findings)


if __name__ == "__main__":
    main()
