# AI DLC Phase Reference

## BOOTSTRAP PHASE

Runs once per intent before inception. Orchestrator drives this directly — not in `workflow.md`.

| Stage | Always/Conditional | Key Output |
| ----- | ------------------ | ---------- |
| Intent Bootstrap | Always | `intent.md`, `bootstrap-context.md`, `intent-state.md`, stub `workflow.md` |
| Workflow Composition | Always | `workflow.md` rewritten with chosen skills, `workflow-rationale.md` |

---

## INCEPTION PHASE

| Stage | Always/Conditional | Key Output |
| ----- | ------------------ | ---------- |
| Reverse Engineering | Brownfield/mixed (per repo, scoped) | `architecture.md`, `tech-stack.md`, `api-surface.md`, `code-structure.md` |
| Requirements Analysis | Always | `requirements.md` (minimal/standard/comprehensive) |
| User Stories | Conditional | `personas.md`, `stories.md` with acceptance criteria |
| Wireframes | Conditional (UI intents only) | `screen-data-map.md`, `screen-structure.md`, `wireframe-guidance.md`, visual wireframes |
| Application Design | Conditional | `components.md`, `component-methods.md`, `cross-cutting.md` |
| ADR Decision Capture (post-Application Design) | Always when stage ran | ADRs in `docs/adr/` for component/pattern choices |
| Units Generation | Conditional | `units-of-work.md`, `units-of-work-story-map.md`, `sequencing.md` |

### Requirements Analysis Depth Guide

**Minimal** — simple, self-contained, clear intent:

- Document intent only
- No clarifying questions
- 1-2 page requirements summary

**Standard** — typical feature work:

- Functional requirements (what the system must do)
- Non-functional requirements (performance, security, reliability)
- Clarifying questions using multiple-choice format
- 3-5 page requirements document

**Comprehensive** — high-risk, complex, or cross-cutting:

- Full functional + NFR requirements
- Traceability matrix linking requirements to user stories
- Acceptance criteria for each requirement
- Risk assessment
- 10+ page requirements document

### Question Format (for clarifying questions)

Use multiple-choice to reduce cognitive load:

```text
**Q1**: [Question]
A) Option one
B) Option two
C) Option three
D) Other (describe)

[Answer]: A
```

Always resolve ambiguities before proceeding. If the user's answer introduces new ambiguity,
follow up before continuing.

---

## CONSTRUCTION PHASE

### Per-Unit Loop

Execute all applicable stages for unit N before starting unit N+1.

```text
For each unit:
  Functional Design? → [ADR Capture]
  → NFR Assessment? → [ADR Capture on tech decisions]
  → NFR Design? → [ADR Capture]
  → Infrastructure Design? → [ADR Capture]
  → Code Generation
After all units:
  Build and Test
```

ADR Capture in brackets runs immediately after the preceding stage is approved.

| Stage | Always/Conditional | Key Output |
| ----- | ------------------ | ---------- |
| Functional Design | Conditional | `business-logic-model.md`, `domain-entities.md`, `business-rules.md` |
| NFR Assessment | Conditional | `nfr-requirements.md`, `tech-stack-decisions.md` |
| NFR Design | Conditional (requires NFR Assessment) | `nfr-design.md` with concrete patterns per NFR |
| Infrastructure Design | Conditional | `infra-design.md` |
| Code Generation | Always | Application code in workspace root, `code-generation-plan.md` |
| Build and Test | Always | 5 instruction files |

### Code Generation Plan Format

```markdown
## Code Generation Plan: {unit-name}

### Files to Create
- [ ] `src/module/file.ts` — description
- [ ] `src/module/file.test.ts` — unit tests

### Functions to Implement
- [ ] `functionName(params)` — description

### Artifacts to Update
- [ ] `README.md` — add usage section
```

After user approves the plan, execute each item and mark `[x]` immediately.

### Build and Test Stage

Produce all 5 instruction files even if some sections are "N/A for this project":

- `build-instructions.md` — how to build all units
- `unit-test-instructions.md` — how to run unit tests
- `integration-test-instructions.md` — how to test cross-unit interactions
- `performance-test-instructions.md` — load/perf testing (or "N/A")
- `build-and-test-summary.md` — one-page summary of all above

---

## OPERATIONS PHASE

Currently a placeholder. When the user asks about deployment, guide them based on their
specific platform (AWS, GCP, Azure, Kubernetes, etc.) using appropriate skills from
the `cloud/` or `kubernetes/` plugin families.

Future stages planned:

- Deployment Planning
- Monitoring and Observability Setup
- Incident Response Runbooks
- Production Readiness Checklist
