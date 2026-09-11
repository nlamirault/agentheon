---
name: dep-version-drift
schedule: "0 6 1 * *"
skill: ci-cd-and-automation
deliver: slack
summary: Monthly toolchain drift report — inconsistent or EOL language/tool versions across all repos.
---

Report toolchain version drift across all my GitHub owners.

{{TARGETS}}

Repos pin language and tool versions in many places; they drift apart and reach
end-of-life silently. This is the version-consistency lens — not security (that
is Nemesis) — so report divergence and EOL, not CVEs. Read-only report.

Steps:
1. Repo list:   gh repo list <owner> --no-archived --source --limit 100 --json name,defaultBranchRef  (for each owner)
2. Version sources: per repo, read whichever exist on the default branch — .tool-versions, .nvmrc, go.mod (go directive), .python-version, package.json engines, and setup-* action `*-version:` keys in .github/workflows/*
3. Group by tool: collect the pinned version of each tool (node, go, python, etc.) across all repos
4. Divergence: flag tools pinned to 2+ different major/minor versions across repos
5. EOL: flag any pinned version past its published end-of-life (e.g. Node < 18, Go < 1.22, Python < 3.9)

Format:

# Toolchain Drift — [month year]

## End-of-life (upgrade)
[tool — version — repos]

## Divergence (align)
[tool — versions in use — repo breakdown]

## Summary
- Repos scanned: N  |  Tools tracked: N  |  Divergent: N  |  EOL: N

EOL first, then widest divergence. If everything aligns, say:
Toolchain consistent — no drift.
