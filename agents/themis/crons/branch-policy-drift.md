---
name: branch-policy-drift
schedule: "0 10 * * 1"
skill: security-compliance
deliver: slack
summary: Weekly branch-protection consistency audit — required reviews, checks, and signing across all repos.
---

Audit branch-protection consistency across all my GitHub owners.

{{TARGETS}}

Argus flags default branches with no protection at all; this audits whether the
protection that exists is configured *consistently* — same required reviews,
status checks, and signing everywhere. Read-only report.

Steps:
1. Repo list:   gh repo list <owner> --no-archived --source --limit 100 --json name,defaultBranchRef  (for each owner)
2. Protection:  per repo default branch, gh api repos/<owner>/<repo>/branches/<branch>/protection  (skip 404 = unprotected, Argus owns that)
3. Extract per repo: required_pull_request_reviews.required_approving_review_count, required_status_checks (strict + contexts), required_signatures, enforce_admins, allow_force_pushes
4. Baseline: treat the most common configuration across all repos as the baseline
5. Drift: flag each protected repo that deviates from the baseline, naming the field

Format:

# Branch Policy Drift — week of [date]

## Baseline
[required reviews: N | strict checks: yes/no | signed commits: yes/no | enforce admins: yes/no]

## Drift from baseline
[repo — field — actual vs baseline]

## Weaker than baseline (priority)
[repo — field — how it is weaker]

## Summary
- Protected repos: N  |  On baseline: N  |  Drifting: N

Weaker-than-baseline first. If all protected repos match, say:
Branch policy consistent — no drift.
