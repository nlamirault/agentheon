---
name: a11y-audit
schedule: "0 8 * * 2"
skill: web-accessibility
deliver: slack
summary: Weekly accessibility audit — axe scan of every published site URL across all repos.
owners:
  - nlamirault
  - portefaix
  - pilotariak
---

Audit web accessibility across all my GitHub owners.

Owners: nlamirault, portefaix, pilotariak

Accessibility regresses silently between releases. URLs are derived from the
repos themselves — no external inventory needed. Read-only report; do not edit
any site.

Steps:
1. Repo list:   gh repo list <owner> --no-archived --source --limit 100 --json name,homepageUrl,hasPages  (for each owner)
2. Target URLs: collect each non-empty homepageUrl; for repos with hasPages, add the GitHub Pages URL (gh api repos/<owner>/<repo>/pages --jq .html_url, skip 404). De-dupe.
3. Scan: run an axe-core accessibility scan on each URL (npx @axe-core/cli <url>, or equivalent). If no runner is available, report that and list the URLs that would be scanned.
4. Collect: per URL, count violations by impact (critical, serious, moderate, minor) with the top rule ids

Format:

# Accessibility Audit — week of [date]

## Critical & serious (fix)
[URL — rule — impact — element count]

## Moderate & minor
[URL — rule — count]

## Summary
- URLs scanned: N  |  Critical: N  |  Serious: N  |  Clean URLs: N

Group by URL, critical first. If every URL passes, say:
Accessibility clean — no violations.
