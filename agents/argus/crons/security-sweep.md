---
name: security-sweep
schedule: "0 7 * * 1"
skill: security-and-hardening
deliver: telegram
summary: Weekly security posture sweep — code scanning and secret scanning alerts across all repos.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Sweep the security posture across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Read-only report built from GitHub's own scanners. Never print a secret value —
report only its location and type so a leak is not widened.

Steps:
1. Repo list:      gh repo list <owner> --no-archived --source --limit 100 --json name  (for each owner)
2. Code scanning:  per repo, gh api repos/<owner>/<repo>/code-scanning/alerts --jq '[.[] | select(.state=="open")]'  (skip 404 = disabled)
3. Secret scanning: per repo, gh api repos/<owner>/<repo>/secret-scanning/alerts --jq '[.[] | select(.state=="open")]'  (skip 404 = disabled)
4. Branch protection: per repo default branch, flag if protection is absent

Format:

# Security Sweep — week of [date]

## Secret scanning (urgent)
[repo — secret type — location — created — REDACT the value]

## Code scanning
[repo — rule — severity — path:line — count]

## Unprotected default branches
[repo — default branch]

## Scanners disabled
[repos returning 404 for code or secret scanning]

Order: secrets first, then code scanning by severity. If clean, say:
Posture clean — no open security alerts.
