# User Stories — Validation Spec

## Inputs

- Artifacts: `personas.md`, `stories.md`
- Answered question file: `inception/user-stories/user-stories-questions.md`
- Upstream: `requirements.md`

## Rules

1. Both `personas.md` and `stories.md` must be present and non-empty. If there are no
   human personas, `personas.md` must state this explicitly.
2. Every story must follow INVEST criteria and have verifiable pass/fail acceptance criteria
   in Given/When/Then format.
3. Every story must have a unique `S-<n>` ID and a `Requirements:` line listing the
   `FR-<n>`/`NFR-<n>` identifiers it addresses.
4. Every FR and NFR in `requirements.md` must be addressed by at least one story.
   Any uncovered requirement must be documented with an explicit reason.
5. Stories must cover all system layers implied by `requirements.md` — not just
   user-facing behaviour.
6. Personas must be grounded in the domain and requirements — not generic archetypes.
7. No two stories may describe the same behaviour. Overlapping stories must be consolidated.
