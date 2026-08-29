# AI DLC Artifacts Reference

Complete listing of all documents produced by each stage.

## org-ai-kb Layout

`org-ai-kb/` lives at the workspace root (default) or at an org-level path configured during
`intent-bootstrap`. It is separate from application code and should be gitignored or kept in a
dedicated repository. It persists across projects.

```
org-ai-kb/
├── codekb/                           RE-generated knowledge per repo
│   └── <repo-name>/
│       ├── summary.md                tech stack, purpose, ownership
│       ├── architecture.md           component diagram (RE-generated)
│       ├── intent-history.md         which intents touched this repo
│       └── engineering/              per-intent RE snapshots
└── aidlc-docs/                       AI-DLC intent artifacts
    └── intent-<nnn>-<slug>/
```

### codekb/<repo-name>/

Populated by reverse-engineering. Reused by workflow-composition to skip RE when hydrated.

- `summary.md` — tech stack, purpose, team ownership
- `architecture.md` — component diagram, interaction patterns (updated each RE run)
- `intent-history.md` — ordered list of intents that touched this repo (latest = last entry)
- `engineering/` — per-intent RE snapshots: `intent-<nnn>-<slug>/` subdirs with full RE artifacts

## Intent Directory Layout

```
org-ai-kb/aidlc-docs/
└── intent-<nnn>-<slug>/
    ├── intent-prompt.md              verbatim prompt
    ├── intent.md                     summary, slug, type, classification
    ├── workflow.md                   one skill per line (post-composition)
    ├── state/
    │   └── intent-state.md          state machine table
    ├── audit/
    │   └── intent-audit.md          append-only interaction log
    ├── bootstrap/
    │   ├── intent-bootstrap/
    │   │   └── bootstrap-context.md
    │   └── workflow-composition/
    │       └── workflow-rationale.md
    ├── inception/
    │   ├── reverse-engineering/<scope>/  (brownfield, per repo)
    │   ├── requirements-analysis/
    │   ├── user-stories/
    │   ├── wireframes/
    │   ├── application-design/
    │   └── units-generation/
    └── construction/
        ├── <unit-name>/
        │   ├── functional-design/
        │   ├── nfr-assessment/
        │   ├── nfr-design/
        │   ├── infrastructure-design/
        │   └── code/
        └── build-and-test/
```

ADRs live in the **workspace root** alongside application code — `docs/adr/` (not in `org-ai-kb/`).

---

## Bootstrap Artifacts

### intent-<nnn>-<slug>/intent.md

- Verbatim prompt, one-paragraph summary, slug, type (feature/bug fix/migration/refactor/prototype)

### intent-<nnn>-<slug>/state/intent-state.md

Maintained throughout. State machine table — one row per skill, updated at each step.
Format: `references/state-schema.md`.

### intent-<nnn>-<slug>/audit/intent-audit.md

Append-only log. Every user input and AI response recorded with ISO 8601 timestamp.
**Never overwrite** — always read first, then append.

### intent-<nnn>-<slug>/workflow.md

Rewritten by workflow-composition. One line per chosen downstream skill.
Format: `references/workflow-format.md`.

---

## Inception Artifacts

### inception/reverse-engineering/<scope>/

- `business-overview.md` — what the system does, key business transactions
- `architecture.md` — component diagram (Mermaid), interaction patterns
- `tech-stack.md` — languages, frameworks, runtimes, versions
- `api-surface.md` — endpoints, contracts, external integrations
- `dependencies.md` — libraries, services, third-party dependencies
- `code-structure.md` — directory layout, module boundaries, entry points

### inception/requirements-analysis/

- `requirements.md` — functional and non-functional requirements
- `traceability-matrix.md` — (comprehensive depth only)

### inception/user-stories/

- `personas.md` — user types, goals, pain points
- `stories.md` — user stories (`S-<n>`) with Given/When/Then acceptance criteria

### inception/wireframes/

- `screen-data-map.md` — per screen: purpose, data in/out, actions, source stories
- `screen-structure.md` — screen inventory, navigation map, component tree
- `wireframe-guidance.md` — code-generation instructions: placement, interaction, responsive, states
- `wireframes/<screen-name>.svg` or `.html` — visual wireframes per screen

### inception/application-design/

- `components.md` — component/service definitions with responsibilities
- `component-methods.md` — key operations with signatures
- `component-dependencies.md` — dependency graph
- `services.md` — external services and APIs
- `cross-cutting.md` — auth, logging, error handling, observability patterns
- `data-models.md` — (if data-intensive) high-level schemas
- `api-contracts.md` — (if API surface defined)
- `event-catalog.md` — (if event-driven)

### inception/units-generation/

- `units-of-work.md` — unit definitions with IDs, descriptions, owning components
- `units-of-work-story-map.md` — `S-<n>` story → unit mapping
- `sequencing.md` — dependency graph, build order, parallelism

---

## Construction Artifacts

### construction/<unit-name>/functional-design/

- `business-logic-model.md` — business workflows, triggers, decision points (Mermaid sequence diagrams)
- `domain-entities.md` — entities, attributes, relationships, lifecycle states
- `business-rules.md` — rule definitions, invariants, validation constraints
- `data-flow.md` — (if complex integrations) how data moves between components

### construction/<unit-name>/nfr-assessment/

- `nfr-requirements.md` — NFRs per category with targets and traceability to `requirements.md`
- `tech-stack-decisions.md` — `TSD-<n>` per technology: choice, alternatives, rationale, trade-offs

### construction/<unit-name>/nfr-design/

- `nfr-design-patterns.md` — concrete patterns per NFR with `TSD-<n>` traceability:
  caching, scaling, availability, security, retry/circuit-breaker, observability, data retention
- `logical-components.md` — new infrastructure-agnostic components introduced by patterns:
  position in topology, interface, failure mode, configuration defaults

### construction/<unit-name>/infrastructure-design/

- `infrastructure-design.md` — per-service infrastructure: compute, storage, networking, IAM,
  environments, cost estimates per service
- `deployment-architecture.md` — system-level: rollout strategy, scaling triggers, failover/RTO-RPO
  mapping, inter-unit connectivity, IaC recommendation

### construction/<unit-name>/code/

Summaries only — actual code lives in the workspace root:

- `code-generation-plan.md` — approved plan with final checkbox states
- `implementation-notes.md` — key decisions, deviations from plan

### construction/build-and-test/

- `build-instructions.md`
- `unit-test-instructions.md`
- `integration-test-instructions.md`
- `performance-test-instructions.md`
- `build-and-test-summary.md`

---

---

## ADR Artifacts

### docs/adr/

Created by ADR Decision Capture after each decision-producing stage. Lives at the repository root
alongside application code — not inside `aidlc-docs/`.

**Naming**: `{NNN}-{kebab-case-decision}.md` — sequential, zero-padded to three digits.

**Created after Application Design:**
- One ADR per component/service architectural pattern selected
- One ADR per integration style chosen (sync/async, protocol selection)

**Created after Functional Design:**
- One ADR per significant data model approach (relational vs document, schema strategy)
- One ADR per algorithm or business rule implementation pattern with evaluated alternatives

**Created after NFR Design:**
- One ADR per technology selected to fulfil an NFR (caching library, auth framework, observability stack)
- One ADR per cross-cutting pattern adopted (retry strategy, circuit breaker, API versioning)

**Created after Infrastructure Design:**
- One ADR per cloud service selection (compute platform, database service, messaging service)
- One ADR per significant networking or security topology decision

**Status lifecycle**: All AIDLC-generated ADRs start as `✅ Accepted` — the stage approval is the
decision point. To supersede, create a new ADR and update the old one's status to `⌛️ Superseded`
with a reference to the new number.

**Index**: Maintain `docs/adr/README.md` as an index table: number, title, status, date, AIDLC stage.
Rebuild this index after each Decision Capture run.

---

## Mermaid Diagram Standards

Always validate Mermaid syntax before writing to file. Key rules:

- Use `graph TD` for flowcharts (top-down)
- Use `sequenceDiagram` for interaction flows
- Use `classDiagram` for domain models
- Escape special characters in node labels with quotes
- Test complex diagrams with a simple render check before including

If Mermaid rendering is uncertain, provide ASCII art as a fallback and note
that a Mermaid version is also available.

---

## Session Continuity

When resuming a session:

1. Find in-progress intents: `org-ai-kb/aidlc-docs/intent-*/state/intent-state.md`
2. Read `intent-state.md` for the chosen intent to find the last step and its status
3. Read the last 10 entries in `<intent-dir>/audit/intent-audit.md` for context
4. Load the most recent artifacts for the active skill
5. Tell the user: "Resuming intent [slug] — [skill] at [step:status]. Continue?"

Never restart from scratch when state exists.
