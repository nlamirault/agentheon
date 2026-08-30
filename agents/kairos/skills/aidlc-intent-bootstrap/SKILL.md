---
name: "aidlc-intent-bootstrap"
description: "Bootstraps a new AI-DLC intent by creating the directory skeleton, classifying greenfield/brownfield, and writing intent.md and bootstrap-context.md before workflow.md exists."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "2.0.0"
  service:
  - ai
  - agent
  task: [configure, build]
  persona: [developer]
  workload: [ai]
phase: bootstrap
stage: intent-bootstrap
per-unit: false
human-clarification: false
plan-creation: false
plan-verification: false
artefact-verification: false
---

# Intent Bootstrap

Bootstraps an intent: confirms the intent slug, picks the intent number, creates the directory
skeleton, classifies greenfield/brownfield, writes `intent.md` and `bootstrap-context.md`.

Runs before `workflow.md` exists. Creates all files that downstream skills depend on.

## Questions (auto-answered, no human consultation)

Ask only what cannot be inferred. Determine answers from workspace scan; record rationale in
`bootstrap-context.md`:

- **org-ai-kb location** — only if it does not yet exist and was not volunteered.
  Default: `<workspace-root>/org-ai-kb/`
- **Slug** — generate kebab-case from the intent statement; present for override if ambiguous
- **Classification** — greenfield (no code) / brownfield / mixed
- **Repos in scope** — brownfield/mixed: list affected repos
- **Codekb status** — brownfield/mixed: hydrated / partial / missing per repo (determines if RE needed)
- **Intent type** — feature, bug fix, migration, refactor, prototype

## Execution Steps

1. Ensure `org-ai-kb/aidlc-docs/` exists (create if needed)
2. Pick the next `<nnn>` (zero-padded) by listing existing `org-ai-kb/aidlc-docs/intent-*` directories
3. Create `org-ai-kb/aidlc-docs/intent-<nnn>-<slug>/` with subdirs `state/`, `audit/`, `bootstrap/intent-bootstrap/`
4. Write `intent-prompt.md` (verbatim prompt) at the intent root
5. Initialize `state/intent-state.md` from state schema header (see `references/state-schema.md`)
6. Initialize `audit/intent-audit.md` with a header entry
7. Write `workflow.md` with exactly one line: `workflow-composition ...intent.md bootstrap/intent-bootstrap/bootstrap-context.md`
8. Write `intent.md` at intent root
9. Write `bootstrap-context.md` in `bootstrap/intent-bootstrap/`

## Output

### intent.md (intent root)

- **Prompt** — verbatim
- **Summary** — one paragraph
- **Slug**
- **Type** — feature / bug fix / migration / refactor / prototype

### bootstrap-context.md (bootstrap/intent-bootstrap/)

- **Classification** — greenfield / brownfield / mixed (with rationale)
- **Repos in scope** — list, or "none"
- **Codekb status** — hydrated / partial / missing per repo (or "n/a" for greenfield)
- **Reverse-engineering** — needed per repo (and why) or not needed
- **Intent type** — with rationale
