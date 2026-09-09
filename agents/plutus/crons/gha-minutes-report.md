---
name: gha-minutes-report
schedule: "0 8 1 * *"
skill: cost-management
deliver: slack
summary: Monthly GitHub Actions minutes report — usage vs quota and top-burning repos across all owners.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Report GitHub Actions minutes usage across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

CI minutes are the one cloud cost visible without cloud credentials. Runs on the
1st so it reads the previous billing cycle. Read-only report.

Steps:
1. Per owner billing: gh api /users/<owner>/settings/billing/actions --jq '{total: .total_minutes_used, included: .included_minutes, paid: .total_paid_minutes_used, breakdown: .minutes_used_breakdown}'  (skip 403 = no access)
2. Quota %: compute total_minutes_used / included_minutes per owner
3. Top repos: where per-repo data is available, rank repos by minutes consumed
4. Trend: compare total vs the figure from last month's report if present in channel history; otherwise report absolute only

Format:

# Actions Minutes — [month year]

## Per owner
[owner — used / included — % of quota — paid overage]

## Top-burning repos
[repo — minutes — % of owner total]

## Summary
- Total minutes: N  |  Overage cost: $N  |  MoM change: +/-N%

Flag any owner over 80% of quota first. If usage is negligible, say:
Minutes well within quota — nothing to flag.
