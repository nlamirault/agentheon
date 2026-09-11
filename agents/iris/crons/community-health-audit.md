---
name: community-health-audit
schedule: "0 8 1 * *"
skill: project-bootstrap
deliver: slack
summary: Monthly audit of community health files (README, LICENSE, CoC, CONTRIBUTING, SECURITY) across all repos.
---

Audit community health files across all my GitHub owners.

{{TARGETS}}

Read-only.

Steps:
1. Repo list: gh repo list <owner> --no-archived --source --limit 100 --json name
2. Per repo, GitHub community profile:
   gh api repos/<owner>/<repo>/community/profile --jq '{score:.health_percentage, files:.files}'
3. Flag missing: README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, issue/PR templates
4. Missing description or topics

Format:

# Community Health — month of [date]

## Incomplete (health < 100%)
[repo — score% — missing: file1, file2]

## Missing metadata
[repo — no description / no topics]

Sort by score asc. If all complete: All repos fully documented.
