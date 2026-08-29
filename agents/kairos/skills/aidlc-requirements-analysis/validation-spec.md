# Requirements Analysis — Validation Spec

## Inputs

- Artifact: `requirements.md`
- Answered question file: `inception/requirements-analysis/requirements-analysis-questions.md`
- Upstream: `intent.md`

## Rules

1. All required sections must be present in `requirements.md`. If a section has no content,
   state "None identified" — do not omit the section.
2. Every capability stated in the intent must be traceable to at least one functional or
   non-functional requirement. No capability may be left unaddressed.
3. Functional requirements must be numbered with `FR-<n>` IDs and be verifiable as pass/fail.
   No vague or purely qualitative statements without measurable criteria.
4. Non-functional requirements must include measurable criteria where possible
   (e.g. "p95 < 200ms", "99.9% uptime"). Pure qualitative statements are a fail.
5. Assumptions must be explicitly flagged as assumptions, not stated as facts.
