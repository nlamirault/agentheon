---
name: "aidlc-user-stories"
description: "Defines personas and user stories with Given/When/Then acceptance criteria for new user-facing features with multiple user types or complex business rules."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "2.0.0"
  service:
  - ai
  - agent
  task: [build, design]
  persona: [developer]
  workload: [ai]
phase: inception
stage: user-stories
per-unit: false
human-clarification: true
plan-creation: true
plan-verification: true
artefact-verification: true
---

# User Stories

Define personas and user stories with acceptance criteria.

**Include when**: New user-facing features, multiple user types, complex business rules.
**Skip when**: Pure refactoring, isolated bug fixes, infrastructure-only, docs updates.

## Inputs

- `requirements.md`
- RE artifacts if brownfield

## Questions

- Who are the primary and secondary user types?
- Are there admin/operator roles beyond end-users?
- Any known user journey patterns to replicate or diverge from?

## Output (inception/user-stories/)

- `personas.md` — user types: name, role, goals, pain points, technical context
- `stories.md` — user stories with acceptance criteria
  Format: `As a [persona], I want [capability] so that [benefit].`
  Each story: `S-<n>` ID, persona reference, acceptance criteria (Given/When/Then)

## ADR Capture

No ADR capture at this stage.
