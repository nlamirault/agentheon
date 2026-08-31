---
name: weekly-digest
schedule: "0 18 * * 0"
skill: git-workflow
deliver: telegram
summary: Weekly rollup across all GitHub owners — PRs, issues, supply-chain, compliance.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Produce a weekly digest across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Steps:
1. Open PRs:       gh search prs   --owner nlamirault --owner portefaix --owner pilotariak --state open   --limit 50 --json repository,number,title,author,updatedAt
2. Merged (7d):    gh search prs   --owner nlamirault --owner portefaix --owner pilotariak --merged --merged-at '>'$(date -d '7 days ago' +%F) --limit 50 --json repository,number,title
3. Open issues:    gh search issues --owner nlamirault --owner portefaix --owner pilotariak --state open --limit 50 --json repository,number,title,labels,updatedAt
4. Closed (7d):    gh search issues --owner nlamirault --owner portefaix --owner pilotariak --closed --closed-at '>'$(date -d '7 days ago' +%F) --limit 50 --json repository,number,title
5. Dependabot:     per repo, count open alerts (skip 404 = disabled)

Format:

# Weekly Digest — week of [date]

## Highlights
[3-5 bullets: biggest movements, anything needing attention]

## Pull Requests
- Open: N  |  Merged this week: N
[per-owner breakdown, oldest-open PRs first]

## Issues
- Open: N  |  Closed this week: N  |  Needs triage: N

## Supply chain
- Repos with open Dependabot alerts: [list + counts]

## Compliance
- PRs missing DCO / license headers: [list]

If a week was completely quiet, say: Quiet week — nothing notable.
