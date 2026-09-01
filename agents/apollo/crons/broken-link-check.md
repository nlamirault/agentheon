---
name: broken-link-check
schedule: "0 9 * * 3"
skill: documentation-and-adrs
deliver: telegram
summary: Weekly docs link check — crawl README and docs for dead links across all repos.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Check documentation links across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Docs rot silently — a link is fine at merge and dead months later. Read-only
report; do not edit any file.

Steps:
1. Repo list:   gh repo list <owner> --no-archived --source --limit 100 --json name,defaultBranchRef  (for each owner)
2. Doc sources: per repo, list README.md plus any *.md under docs/ on the default branch (gh api repos/<owner>/<repo>/git/trees/<branch>?recursive=1)
3. Extract links: pull every http(s) URL from those Markdown files
4. Probe: HEAD each unique URL (fall back to GET on 405); flag 4xx and 5xx. De-dupe URLs so each is probed once. Skip known-flaky hosts that rate-limit HEAD (e.g. linkedin, twitter/x) and note them as skipped.

Format:

# Broken Links — week of [date]

## Dead (4xx/5xx)
[repo — file — URL — status code]

## Skipped (rate-limited hosts)
[URL — host]

## Summary
- Repos scanned: N  |  URLs probed: N  |  Broken: N

Group by repo, worst status first. If all links resolve, say:
All links healthy — nothing broken.
