---
name: stale-workflow-sweep
schedule: "0 7 15 * *"
skill: cicd-github-actions
deliver: slack
summary: Monthly CI hygiene sweep — deprecated runners, tag-pinned actions, and dead workflows across all repos.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Sweep GitHub Actions workflow hygiene across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Workflows rot: runners reach end-of-life, actions stay pinned by mutable tag
(supply-chain risk), and files linger with zero runs. Read-only report; do not
edit any workflow.

Steps:
1. Repo list:    gh repo list <owner> --no-archived --source --limit 100 --json name,defaultBranchRef  (for each owner)
2. Workflow files: per repo, list .github/workflows/*.{yml,yaml} on the default branch (gh api repos/<owner>/<repo>/git/trees/<branch>?recursive=1)
3. Deprecated runners: flag any `runs-on:` using ubuntu-20.04, macos-12, or other EOL images
4. Tag-pinned actions: flag `uses:` referencing a mutable tag (e.g. @v4, @main) instead of a full commit SHA
5. Dead workflows: per workflow, gh run list --workflow=<file> --limit 1 --json createdAt — flag any with 0 runs or last run > 90 days ago

Format:

# Workflow Hygiene — [month year]

## Deprecated runners (fix soon)
[repo — workflow — runner]

## Tag-pinned actions (supply-chain)
[repo — workflow — action@tag]

## Dead workflows (0 runs or > 90d)
[repo — workflow — last run]

## Summary
- Repos scanned: N  |  Workflows: N  |  Findings: N

Group by repo, deprecated runners first. If everything is clean, say:
Workflows healthy — nothing stale.
