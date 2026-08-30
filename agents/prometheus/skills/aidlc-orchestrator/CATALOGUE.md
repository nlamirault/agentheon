# AI DLC Skill Catalogue

Available skills by phase. Orchestrator reads this to compose adaptive workflows.

## Skill Flags

| Flag | Default | Meaning |
|---|---|---|
| `human-clarification` | true | Human answers clarification questions before execution |
| `plan-creation` | true | Builder writes a plan file before execution |
| `plan-verification` | true | Human approves the plan before execution |
| `artefact-verification` | true | Human reviews artifacts after validation |

`false` on `plan-creation` skips the planning step entirely; `false` on `human-clarification` means the builder auto-answers and proceeds without consulting the human.

## Bootstrap Phase

Driven by the orchestrator's pre-loop — never listed in `workflow.md`.

| Skill | Stage | Per-Unit | Clar | Plan | Plan-Verify | Artefact-Verify |
|---|---|---|---|---|---|---|
| intent-bootstrap | intent-bootstrap | No | false | false | n/a | false |
| workflow-composition | workflow-composition | No | false | false | n/a | true |

## Inception Phase

| Skill | Stage | Per-Unit | Clar | Plan | Plan-Verify | Artefact-Verify |
|---|---|---|---|---|---|---|
| reverse-engineering | reverse-engineering | No (scoped per repo) | true | true | true | true |
| requirements-analysis | requirements-analysis | No | true | true | true | true |
| user-stories | user-stories | No | true | true | true | true |
| wireframes | wireframes | No | true | true | true | true |
| application-design | application-design | No | true | true | true | true |
| units-generation | units-generation | No | true | true | true | true |

## Construction Phase

| Skill | Stage | Per-Unit | Clar | Plan | Plan-Verify | Artefact-Verify |
|---|---|---|---|---|---|---|
| functional-design | functional-design | Yes | true | true | true | true |
| nfr-assessment | nfr-assessment | Yes | true | true | true | true |
| nfr-design | nfr-design | Yes | true | true | true | true |
| infrastructure-design | infrastructure-design | Yes | true | true | true | true |
| code-generation | code-generation | Yes | true | true | true | true |
| build-and-test | build-and-test | No | true | true | true | true |

## Composition Rules

Three skills are always-on: `requirements-analysis`, `code-generation`, `build-and-test`.
Everything else is conditional. Skip aggressively when the intent is narrow, single-actor,
single-component, or pure implementation. Include only when the skill's output would
meaningfully shape what comes next.

| Skill | Include when |
|---|---|
| reverse-engineering | Brownfield/mixed — once per affected repo (skip if codekb hydrated) |
| user-stories | New user-facing features, multiple user types, complex business rules |
| wireframes | Intent has UI-facing stories |
| application-design | New components or service boundaries; refactors changing component shape |
| units-generation | Multiple independent units of work |
| functional-design | New data models, complex business logic, non-trivial business rules |
| nfr-assessment | Performance/security/scalability concerns, or any tech stack selection |
| nfr-design | Always if `nfr-assessment` ran |
| infrastructure-design | Cloud resources needed, deployment changes, new environments |

For worked composition examples by intent type, see `../aidlc-workflow-composition/SKILL.md`.

## Sub-Skill Instructions

Detailed instructions per skill live in `../aidlc-<skill-name>/SKILL.md`.
