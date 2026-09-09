---
name: license-audit
schedule: "0 9 1 * *"
skill: security-compliance
deliver: slack
summary: Monthly governance audit — LICENSE, SPDX headers, DCO, and contribution files across all repos.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Audit repository governance files across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Repo-level compliance hygiene: the files that must exist for an open-source
project to be well-governed. This is the repo-policy lens — Iris checks DCO at
the PR level, this checks the files are present. Read-only report.

Steps:
1. Repo list:   gh repo list <owner> --no-archived --source --limit 100 --json name,licenseInfo,defaultBranchRef  (for each owner)
2. License:     flag repos with no licenseInfo, or a LICENSE file absent from the default branch
3. DCO:         per repo, check a DCO file exists (gh api repos/<owner>/<repo>/contents/DCO — 404 = missing)
4. Contribution: per repo, check CONTRIBUTING.md and CODE_OF_CONDUCT.md exist
5. SPDX headers: sample source files (gh search code 'SPDX-License-Identifier' repo:<owner>/<repo>) — flag repos with zero matches as likely missing headers

Format:

# Governance Audit — [month year]

## Missing license
[repo]

## Missing DCO
[repo]

## Missing contribution files
[repo — CONTRIBUTING / CODE_OF_CONDUCT]

## Likely missing SPDX headers
[repo]

## Summary
- Repos scanned: N  |  Fully compliant: N  |  Gaps: N

License gaps first. If every repo is compliant, say:
Governance clean — all files present.
