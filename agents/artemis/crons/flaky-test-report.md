---
name: flaky-test-report
schedule: "0 9 * * 5"
skill: testing
deliver: telegram
summary: Weekly CI reliability report — flaky and slow test signals from recent workflow runs.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Report CI reliability across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Flaky tests erode trust in the suite — surface the retry-to-green and the
consistently red before they get muted. Read-only report over the last 7 days
of workflow runs.

Steps:
1. Repo list:      gh repo list <owner> --no-archived --source --limit 100 --json name  (for each owner)
2. Recent runs:    per repo, gh run list --repo <owner>/<repo> --created '>'$(date -d '7 days ago' +%F) --limit 100 --json workflowName,headBranch,conclusion,event,databaseId,createdAt
3. Flaky signal:   a run that was re-run and flipped failure -> success on the same commit (compare attempts via gh api repos/<owner>/<repo>/actions/runs/<id>/attempts). Flag workflows with the highest flip rate.
4. Chronic red:    workflows failing on the default branch more than once this week.
5. Slow trend:     from run durations, flag the slowest workflows (top 5 by median minutes).

Format:

# CI Reliability — week of [date]

## Flaky (passed on re-run)
[repo — workflow — flips this week — flip rate]

## Chronic red (default branch)
[repo — workflow — failures this week]

## Slowest workflows
[repo — workflow — median minutes]

## Summary
- Runs analyzed: N  |  Flaky workflows: N  |  Chronic red: N

Order by flip rate, flakiest first. If the suite is stable, say:
CI stable — no flaky or chronic-red workflows this week.
