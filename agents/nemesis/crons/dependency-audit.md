---
name: dependency-audit
schedule: "0 8 * * 1"
skill: audit-and-reduce-dependencies
deliver: telegram
summary: Weekly supply-chain scan — open Dependabot alerts and outdated dependencies across all repos.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Audit dependency health across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Read-only report. Do not open PRs or push changes — I decide what to bump.

Steps:
1. Repo list:        gh repo list <owner> --no-archived --source --limit 100 --json name,primaryLanguage  (for each owner)
2. Dependabot alerts: per repo, gh api repos/<owner>/<repo>/dependabot/alerts --jq '[.[] | select(.state=="open")]'  (skip 404 = disabled)
3. Group open alerts by severity (critical / high / medium / low)
4. Outdated majors: where an ecosystem lockfile is present, note dependencies more than one major version behind (best-effort, skip if not resolvable)

Format:

# Dependency Audit — week of [date]

## Critical & high (act now)
[per alert: repo — package — severity — advisory summary — fixed-in version]

## Medium & low
[repo — count by severity]

## Dependabot disabled
[repos with alerts API returning 404 — worth enabling]

## Outdated majors
[repo — package — current -> latest]

Sort by severity, critical first. If clean, say:
Supply chain clean — no open alerts.
