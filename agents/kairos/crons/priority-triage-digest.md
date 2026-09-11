---
name: priority-triage-digest
schedule: "0 9 * * 4"
skill: planning-and-task-breakdown
deliver: slack
summary: Weekly priority digest — high-priority stale issues, milestone slippage, and unlabeled backlog.
---

Produce a priority-and-milestone digest across all my GitHub owners.

{{TARGETS}}

Iris triages stale issues by age; this is the priority-and-milestone lens — what
matters most and whether milestones are on track. Read-only report.

Steps:
1. Open issues:  gh search issues --owner nlamirault --owner portefaix --owner pilotariak --state open --limit 100 --json repository,number,title,labels,milestone,createdAt,updatedAt
2. High priority stale: issues labelled priority (priority/high, P0, P1, critical, urgent — match loosely) with idle > 7 days
3. Milestones: per repo, gh api repos/<owner>/<repo>/milestones --jq '.[] | {title, due_on, open_issues, closed_issues}' — flag milestones past due_on with open issues, or due within 14 days with > 30% still open
4. Unlabeled backlog: open issues with no labels, oldest first
5. Priority mix: count open issues per priority label

Format:

# Priority Digest — week of [date]

## High priority, stalled (> 7d idle)
[repo #n — title — priority — idle N days]

## Milestone slippage
[repo — milestone — due — open/closed — status: overdue / at-risk]

## Unlabeled backlog (triage)
[repo #n — title — age N days]

## Priority mix
[priority label — open count]

## Summary
- Open issues: N  |  High-priority stalled: N  |  Milestones at risk: N  |  Unlabeled: N

Stalled high-priority first, then slipping milestones. If nothing needs
attention, say:
Priorities on track — nothing pressing.
