---
name: stale-issue-triage
schedule: "0 9 * * *"
skill: git-workflow
deliver: telegram
summary: Daily sweep for issues and PRs gone quiet — surface what needs a nudge, a label, or a close.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Triage stale issues and pull requests across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

An item is stale when it has had no update in 30+ days. Do not comment on or
modify anything — this is a read-only report I act on myself.

Steps:
1. Stale open issues: gh search issues --owner nlamirault --owner portefaix --owner pilotariak --state open --updated '<'$(date -d '30 days ago' +%F) --sort updated --limit 50 --json repository,number,title,labels,updatedAt,comments
2. Stale open PRs:    gh search prs    --owner nlamirault --owner portefaix --owner pilotariak --state open --updated '<'$(date -d '30 days ago' +%F) --sort updated --limit 50 --json repository,number,title,author,updatedAt
3. No-label issues:   from the open-issue set, flag any with zero labels (needs triage)
4. Awaiting-response: PRs where the last activity was mine and the author has gone quiet 14+ days

Format:

# Stale Triage — [date]

## Needs a decision (oldest first)
[per item: repo#number — title — N days idle — suggested action: nudge / label / close]

## Untriaged (no labels)
[repo#number — title — N days old]

## PRs waiting on author
[repo#number — title — author — N days since last reply]

Cap each section at 10 items, oldest first. If nothing is stale, say:
Nothing stale — everything is fresh.
