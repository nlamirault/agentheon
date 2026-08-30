# Intent Bootstrap — Validation Spec

## Inputs

- Artifacts (intent root): `intent-prompt.md`, `intent.md`, `workflow.md`,
  `state/intent-state.md`, `audit/intent-audit.md`
- Artifact (bootstrap dir): `bootstrap-context.md`
- Answered question file: `bootstrap/intent-bootstrap/intent-bootstrap-questions.md`
- Upstream: none — receives intent statement directly

## Rules

1. Intent directory exists under `org-ai-kb/aidlc-docs/` and follows the pattern
   `intent-<nnn>-<slug>/` where `<nnn>` is zero-padded 3-digit and `<slug>` is kebab-case.
2. `intent-prompt.md` exists at the intent root and contains the verbatim user prompt.
3. `state/intent-state.md` exists and matches the header format from `references/state-schema.md`:
   intent name, created/updated timestamps, Workflow Progress table header.
4. `audit/intent-audit.md` exists and is non-empty.
5. `workflow.md` exists at the intent root and contains exactly one non-comment non-empty line:
   the `workflow-composition` invocation. It must NOT contain an `intent-bootstrap` line.
6. `intent.md` exists and contains: verbatim prompt, summary, slug, and type.
7. `bootstrap-context.md` exists in `bootstrap/intent-bootstrap/` and states:
   classification (greenfield/brownfield/mixed), repos in scope (or "none"), and
   reverse-engineering decision.
8. The slug in `intent.md` matches the slug in the intent directory name.
9. Classification and reverse-engineering decision in `bootstrap-context.md` are consistent
   with answers in the questions file.
