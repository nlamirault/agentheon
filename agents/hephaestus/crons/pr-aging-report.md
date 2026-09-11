---
name: pr-aging-report
schedule: "0 11 * * 1"
skill: incremental-implementation
deliver: slack
summary: Weekly PR aging report — stale, review-blocked, and approved-but-unmerged PRs across all repos.
---

Report open pull-request aging across all my GitHub owners.

{{TARGETS}}

Iris's weekly digest counts PRs; this is the actionable deep view — which PRs are
stuck and why, so they get unstuck. Read-only report.

Steps:
1. Open PRs:    gh search prs --owner nlamirault --owner portefaix --owner pilotariak --state open --limit 100 --json repository,number,title,author,createdAt,updatedAt,isDraft
2. Age & idle:  per PR compute age (now - createdAt) and idle time (now - updatedAt)
3. Review state: per PR, gh pr view <n> --repo <repo> --json reviewDecision,reviews,mergeable
4. Bucket each PR:
   - Approved but unmerged: reviewDecision APPROVED and still open
   - Review-blocked: CHANGES_REQUESTED
   - Awaiting review: REVIEW_REQUIRED and idle > 3 days
   - Stale: idle > 14 days
   - Draft-forever: isDraft and age > 14 days

Format:

# PR Aging — week of [date]

## Approved, ready to merge
[repo #n — title — author — approved N days ago]

## Review-blocked (changes requested)
[repo #n — title — idle N days]

## Awaiting review (> 3d idle)
[repo #n — title — waiting N days]

## Stale (> 14d idle)
[repo #n — title — idle N days]

## Draft-forever (> 14d)
[repo #n — title — age N days]

## Summary
- Open PRs: N  |  Ready to merge: N  |  Blocked: N  |  Stale: N

Approved-ready first — those are free wins. If no PRs are stuck, say:
PRs flowing — nothing stuck.
