---
name: "aidlc-code-generation"
description: "Generates application code and tests for one unit in two parts — plan then generate — always-on construction skill that runs for every unit."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "2.0.0"
  service:
  - ai
  - agent
  task: [build, generate]
  persona: [developer]
  workload: [ai]
phase: construction
stage: code-generation
per-unit: true
human-clarification: true
plan-creation: true
plan-verification: true
artefact-verification: true
---

# Code Generation

Generate application code and tests for one unit. Two-part execution: plan first, then generate.

## Inputs

- `business-logic-model.md`, `domain-entities.md`, `business-rules.md`
- `nfr-design.md` (if ran), `infra-design.md` (if ran)
- `components.md`, `component-methods.md`, `api-contracts.md`
- Wireframe markdown files (if wireframes ran)

## Part 1 — Plan (requires human approval before generation)

Produce a checkbox list of all files, functions, and tests to generate:

```markdown
## Code Generation Plan: {unit-name}

### Files to Create
- [ ] `src/module/file.ts` — description
- [ ] `src/module/file.test.ts` — unit tests for above

### Functions to Implement
- [ ] `functionName(params): ReturnType` — description

### Files to Update
- [ ] `README.md` — add usage section
```

**Wait for explicit approval before proceeding to Part 2.**

## Part 2 — Generate

Execute each item in the approved plan. Mark each item `[x]` immediately when done — never
batch updates. Application code lands in the workspace root. Summaries only in `org-ai-kb/aidlc-docs/`.

## Output

Application code in workspace root (not in `org-ai-kb/aidlc-docs/`).

Summaries in `construction/<unit-name>/code/`:
- `code-generation-plan.md` — the approved plan with final checkbox states
- `implementation-notes.md` — key decisions made during generation, deviations from plan

## Anti-patterns

- Batching checkbox updates — mark `[x]` immediately, not at the end
- Code in `org-ai-kb/aidlc-docs/` — application code belongs in workspace root only
- Silently deviating from the approved plan — record all deviations in `implementation-notes.md`
