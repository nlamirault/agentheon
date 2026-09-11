---
name: release-radar
schedule: "0 9 * * 1"
skill: shipping-and-launch
deliver: slack
summary: Weekly check for repos with merged work sitting unreleased since the last tag.
---

Find repos overdue for a release across all my GitHub owners.

{{TARGETS}}

Read-only. I decide what to cut.

Steps:
1. Repo list: gh repo list <owner> --no-archived --source --limit 100 --json name  (each owner)
2. Latest tag per repo: gh api repos/<owner>/<repo>/tags --jq '.[0].name'  (skip if none)
3. Commits since tag: gh api repos/<owner>/<repo>/compare/<tag>...HEAD --jq '.ahead_by'
4. Days since tag date

Format:

# Release Radar — week of [date]

## Overdue (10+ commits or 30+ days unreleased)
[repo — last tag — N commits ahead — N days since]

## Warming up (any unreleased work)
[repo — N commits ahead]

Sort by commits-ahead desc. If all fresh: Everything shipped — no backlog.
