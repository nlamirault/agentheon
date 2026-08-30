---
name: "aidlc-requirements-analysis"
description: "Transforms the intent into validated functional and non-functional requirements with measurable criteria; always-on skill that runs for every intent."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "2.0.0"
  service:
  - ai
  - agent
  task: [configure, build, review]
  persona: [developer]
  workload: [ai]
phase: inception
stage: requirements-analysis
per-unit: false
human-clarification: true
plan-creation: true
plan-verification: true
artefact-verification: true
---

# Requirements Analysis

Transform the intent into validated requirements. Choose depth based on complexity.

## Inputs

- `intent.md`
- `bootstrap-context.md`
- RE artifacts if brownfield

## Depth Selection

| Depth | When | Size |
|---|---|---|
| Minimal | Simple, self-contained, clear intent | 1-2 pages — intent doc only, no clarifying questions |
| Standard | Typical feature work | 3-5 pages — functional + NFR, clarifying questions |
| Comprehensive | High-risk, complex, or cross-cutting | 10+ pages — full functional + NFR, traceability matrix, risk assessment |

## Questions

Use multiple-choice format (A/B/C/D — D = Other). Resolve all ambiguities before proceeding.
If an answer introduces new ambiguity, follow up before continuing.

```text
**Q1**: [Question]
A) Option one
B) Option two
C) Option three
D) Other (describe)

[Answer]: A
```

## Output (inception/requirements-analysis/)

- `requirements.md` — functional requirements, non-functional requirements (performance, security,
  reliability, scalability, observability), constraints, assumptions
- `traceability-matrix.md` — (comprehensive depth only) requirements → acceptance criteria
