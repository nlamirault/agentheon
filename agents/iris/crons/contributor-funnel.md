---
name: contributor-funnel
schedule: "0 9 * * 2"
skill: git-workflow
deliver: slack
summary: Weekly check that each active repo keeps enough open good-first-issue / help-wanted on-ramps.
---

Audit the contributor on-ramp across all my GitHub owners.

{{TARGETS}}

Read-only.

Steps:
1. good-first-issue count:
   gh search issues --owner nlamirault --owner portefaix --owner pilotariak --state open --label "good first issue" --json repository,number,title
2. help-wanted count:
   gh search issues --owner nlamirault --owner portefaix --owner pilotariak --state open --label "help wanted" --json repository,number,title
3. Stale on-ramps: any good-first-issue open 60+ days (too hard, or unclaimed?)

Format:

# Contributor Funnel — week of [date]

## Under-stocked (active repo, 0 open good-first-issue)
[repo — open help-wanted: N]

## Healthy
[repo — good-first: N — help-wanted: N]

## Stale on-ramps (60+ days unclaimed)
[repo#number — title — N days]

Prioritize repos with recent commits but empty funnel.
