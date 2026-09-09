---
name: first-response-sla
schedule: "0 10 * * 1-5"
skill: git-workflow
deliver: slack
summary: Weekday sweep for unanswered issues/PRs from first-time contributors — respond before they bounce.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Find issues and PRs awaiting a first response across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Read-only. I reply myself.

Steps:
1. Open issues, no maintainer reply, <7d old:
   gh search issues --owner nlamirault --owner portefaix --owner pilotariak --state open --created '>'$(date -d '7 days ago' +%F) --sort created --json repository,number,title,author,comments,createdAt
2. Open PRs same window:
   gh search prs --owner nlamirault --owner portefaix --owner pilotariak --state open --created '>'$(date -d '7 days ago' +%F) --sort created --json repository,number,title,author,createdAt
3. Flag first-time authors (author-association FIRST_TIME_CONTRIBUTOR / NONE)
4. Bucket by age: >48h waiting = breach

Format:

# First-Response SLA — [date]

## Breached (>48h, no reply)
[repo#number — title — author (first-timer?) — N hours waiting]

## Approaching (24-48h)
[repo#number — title — N hours]

Oldest first. If all answered: Inbox zero — everyone got a reply.
