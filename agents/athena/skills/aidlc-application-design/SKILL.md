---
name: "aidlc-application-design"
description: "Defines component/service architecture, interface contracts, and domain model when new components or service boundaries are needed or existing ones are being changed."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "2.0.0"
  service:
  - ai
  - agent
  task: [design, build]
  persona: [developer]
  workload: [ai]
phase: inception
stage: application-design
per-unit: false
human-clarification: true
plan-creation: true
plan-verification: true
artefact-verification: true
---

# Application Design

Define component/service architecture, interface contracts, and domain model.

**Include when**: New components or services needed; service-layer design required;
refactors that change component shape or boundaries.
**Skip when**: Changes stay within existing component boundaries.

## Inputs

- `requirements.md`
- `stories.md`, `personas.md` (if user-stories ran)
- `screen-data-map.md` (if wireframes ran)
- RE artifacts if brownfield

## Questions

- How many components/services? Monolith or distributed?
- Synchronous or async communication between components?
- Shared state management approach?
- External integrations to accommodate?
- Brownfield: What can be reused vs. must be replaced?

## Output (inception/application-design/)

- `components.md` — component/service definitions with responsibilities, interfaces, dependencies
- `component-methods.md` — key operations per component with signatures and contracts
- `component-dependencies.md` — dependency graph between components
- `services.md` — external services, third-party APIs, messaging queues
- `cross-cutting.md` — auth, logging, error handling, observability patterns applied across all components
- `data-models.md` — (if data-intensive) high-level schemas, key entities, relationships
- `api-contracts.md` — (if API surface defined) endpoint contracts, request/response shapes
- `event-catalog.md` — (if event-driven) events, producers, consumers, schemas
- `external-dependencies.md` — (if complex integrations) integration contracts and protocols

## ADR Capture

Run immediately after approval. Create one ADR per:
- Component/service architectural pattern selected
- Integration style chosen (sync/async, protocol selection)
