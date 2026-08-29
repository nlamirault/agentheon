#!/usr/bin/env python3
"""
validate_manifest.py — Static analysis for Kubernetes manifests.

Checks YAML manifests for common misconfigurations that cause production issues.
Outputs a structured report Claude can read and act on.

Usage:
  python3 validate_manifest.py <file-or-dir>
  python3 validate_manifest.py manifest.yaml
  python3 validate_manifest.py k8s/
  cat manifest.yaml | python3 validate_manifest.py -
"""

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML required. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

SEVERITY = {"error": "❌", "warn": "⚠️", "info": "ℹ️"}

DEPRECATED_API_VERSIONS = {
    "extensions/v1beta1": "Use apps/v1 for Deployment/DaemonSet/ReplicaSet/StatefulSet",
    "apps/v1beta1": "Use apps/v1",
    "apps/v1beta2": "Use apps/v1",
    "policy/v1beta1": "Use policy/v1 for PodDisruptionBudget; PodSecurityPolicy removed in 1.25",
    "networking.k8s.io/v1beta1": "Use networking.k8s.io/v1 for Ingress",
}

WORKLOAD_KINDS = {"Deployment", "DaemonSet", "StatefulSet", "Job", "CronJob", "Pod"}


def check_resource_limits(containers: list, path: str) -> list:
    findings = []
    for i, c in enumerate(containers):
        name = c.get("name", f"container[{i}]")
        resources = c.get("resources", {})
        limits = resources.get("limits", {})
        requests = resources.get("requests", {})
        if not limits.get("cpu"):
            findings.append(("warn", path, f"{name}: missing resources.limits.cpu — unbounded CPU can starve other pods"))
        if not limits.get("memory"):
            findings.append(("error", path, f"{name}: missing resources.limits.memory — OOMKill risk without memory limit"))
        if not requests.get("cpu"):
            findings.append(("warn", path, f"{name}: missing resources.requests.cpu — scheduler can't make good placement decisions"))
        if not requests.get("memory"):
            findings.append(("warn", path, f"{name}: missing resources.requests.memory — scheduler can't make good placement decisions"))
    return findings


def check_health_probes(containers: list, path: str) -> list:
    findings = []
    for i, c in enumerate(containers):
        name = c.get("name", f"container[{i}]")
        if not c.get("livenessProbe"):
            findings.append(("warn", path, f"{name}: no livenessProbe — container won't be restarted if it deadlocks"))
        if not c.get("readinessProbe"):
            findings.append(("error", path, f"{name}: no readinessProbe — pod will receive traffic before it's ready"))
    return findings


def check_security_context(spec: dict, path: str) -> list:
    findings = []
    pod_sc = spec.get("securityContext", {})
    containers = spec.get("containers", []) + spec.get("initContainers", [])

    if pod_sc.get("runAsRoot") is True:
        findings.append(("error", path, "pod securityContext.runAsRoot=true — containers run as root"))

    for i, c in enumerate(containers):
        name = c.get("name", f"container[{i}]")
        sc = c.get("securityContext", {})
        if sc.get("privileged") is True:
            findings.append(("error", path, f"{name}: securityContext.privileged=true — full host access, avoid unless absolutely required"))
        if sc.get("allowPrivilegeEscalation") is not False:
            findings.append(("warn", path, f"{name}: allowPrivilegeEscalation not set to false — add securityContext.allowPrivilegeEscalation: false"))
        if not sc.get("readOnlyRootFilesystem"):
            findings.append(("info", path, f"{name}: consider setting readOnlyRootFilesystem: true to prevent runtime writes"))
        run_as_user = sc.get("runAsUser") or pod_sc.get("runAsUser")
        if run_as_user == 0:
            findings.append(("error", path, f"{name}: runAsUser=0 — running as root"))

    return findings


def check_labels(metadata: dict, path: str) -> list:
    findings = []
    labels = metadata.get("labels", {})
    recommended = ["app.kubernetes.io/name", "app.kubernetes.io/version", "app.kubernetes.io/component"]
    missing = [l for l in recommended if l not in labels]
    if missing:
        findings.append(("info", path, f"Missing recommended labels: {', '.join(missing)}"))
    return findings


def check_image_tag(containers: list, path: str) -> list:
    findings = []
    for i, c in enumerate(containers):
        name = c.get("name", f"container[{i}]")
        image = c.get("image", "")
        if image.endswith(":latest") or ":" not in image:
            findings.append(("error", path, f"{name}: image '{image}' uses :latest or no tag — pin to a digest or specific version"))
    return findings


def check_deprecated_api(doc: dict, path: str) -> list:
    findings = []
    api_version = doc.get("apiVersion", "")
    if api_version in DEPRECATED_API_VERSIONS:
        findings.append(("error", path, f"apiVersion '{api_version}' is deprecated. {DEPRECATED_API_VERSIONS[api_version]}"))
    return findings


def analyze_doc(doc: dict, source: str) -> list:
    if not isinstance(doc, dict):
        return []
    findings = []
    kind = doc.get("kind", "")
    metadata = doc.get("metadata", {})
    name = metadata.get("name", "<unnamed>")
    path = f"{source} [{kind}/{name}]"

    findings += check_deprecated_api(doc, path)
    findings += check_labels(metadata, path)

    # Resolve pod spec location
    spec = doc.get("spec", {})
    if kind in ("Deployment", "DaemonSet", "ReplicaSet", "StatefulSet"):
        pod_spec = spec.get("template", {}).get("spec", {})
    elif kind == "CronJob":
        pod_spec = spec.get("jobTemplate", {}).get("spec", {}).get("template", {}).get("spec", {})
    elif kind == "Job":
        pod_spec = spec.get("template", {}).get("spec", {})
    elif kind == "Pod":
        pod_spec = spec
    else:
        return findings

    containers = pod_spec.get("containers", [])
    if not containers:
        return findings

    findings += check_resource_limits(containers, path)
    findings += check_health_probes(containers, path)
    findings += check_security_context(pod_spec, path)
    findings += check_image_tag(containers, path)

    return findings


def analyze_file(filepath: Path) -> list:
    text = filepath.read_text(encoding="utf-8")
    try:
        docs = list(yaml.safe_load_all(text))
    except yaml.YAMLError as e:
        return [("error", str(filepath), f"YAML parse error: {e}")]
    findings = []
    for doc in docs:
        findings += analyze_doc(doc, str(filepath))
    return findings


def print_report(all_findings: list) -> None:
    if not all_findings:
        print("✅ No issues found.")
        return

    by_severity = {"error": [], "warn": [], "info": []}
    for sev, path, msg in all_findings:
        by_severity.get(sev, by_severity["info"]).append((path, msg))

    for sev in ("error", "warn", "info"):
        items = by_severity[sev]
        if not items:
            continue
        label = {"error": "ERRORS", "warn": "WARNINGS", "info": "INFO"}[sev]
        print(f"\n{SEVERITY[sev]} {label} ({len(items)})")
        for path, msg in items:
            print(f"  {path}")
            print(f"    → {msg}")

    errors = len(by_severity["error"])
    warns = len(by_severity["warn"])
    print(f"\n{'─'*50}")
    print(f"Summary: {errors} error(s), {warns} warning(s), {len(by_severity['info'])} info")
    if errors:
        print("Fix errors before deploying to production.")
    sys.exit(1 if errors else 0)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] == "-":
        import tempfile, os
        tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False)
        tmp.write(sys.stdin.read())
        tmp.close()
        paths = [Path(tmp.name)]
    else:
        target = Path(sys.argv[1])
        if target.is_dir():
            paths = sorted(target.rglob("*.yaml")) + sorted(target.rglob("*.yml"))
        else:
            paths = [target]

    all_findings = []
    for p in paths:
        all_findings += analyze_file(p)

    print_report(all_findings)


if __name__ == "__main__":
    main()
