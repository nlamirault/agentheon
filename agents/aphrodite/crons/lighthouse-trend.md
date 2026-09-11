---
name: lighthouse-trend
schedule: "0 8 * * 4"
skill: web-perf
deliver: slack
summary: Weekly Lighthouse trend — performance, SEO, and best-practices scores for every published site URL.
---

Track Lighthouse scores across all my GitHub owners.

{{TARGETS}}

Performance and SEO drift release to release; a weekly trend catches it. URLs are
derived from the repos themselves — no external inventory needed. Read-only
report.

Steps:
1. Repo list:   gh repo list <owner> --no-archived --source --limit 100 --json name,homepageUrl,hasPages  (for each owner)
2. Target URLs: collect each non-empty homepageUrl; for repos with hasPages, add the GitHub Pages URL (gh api repos/<owner>/<repo>/pages --jq .html_url, skip 404). De-dupe.
3. Run: Lighthouse on each URL (npx lighthouse <url> --quiet --chrome-flags="--headless" --output=json). If no runner is available, report that and list the URLs that would be scanned.
4. Collect: per URL the four category scores — performance, accessibility, best-practices, SEO (0-100)
5. Trend: compare each score to the same URL in last week's report from channel history; flag drops of 5+ points

Format:

# Lighthouse Trend — week of [date]

## Regressions (dropped 5+ pts)
[URL — category — this week vs last]

## Below target (< 80)
[URL — category — score]

## Scores
[URL — perf / a11y / best-practices / SEO]

## Summary
- URLs scanned: N  |  Regressions: N  |  Below target: N

Regressions first. If nothing regressed and all scores are healthy, say:
Scores healthy — no regressions.
