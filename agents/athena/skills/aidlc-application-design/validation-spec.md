# Application Design — Validation Spec

## Inputs

- Artifacts (always): `components.md`, `component-methods.md`, `component-dependencies.md`,
  `services.md`, `cross-cutting.md`
- Artifacts (conditional): `data-models.md`, `api-contracts.md`, `event-catalog.md`,
  `external-dependencies.md`
- Answered question file: `inception/application-design/application-design-questions.md`
- Upstream: `requirements.md`, `stories.md`, `personas.md`
- Upstream (if wireframes ran): `screen-data-map.md`

## Rules

1. All five always-on artifacts must be present and non-empty.
2. Conditional artifacts must be present when applicable:
   `data-models.md` if persistence exists; `api-contracts.md` if system exposes APIs;
   `event-catalog.md` if event-driven; `external-dependencies.md` if external integrations
   exist. Omissions must be justified in `components.md`.
3. Every component in `components.md` must appear in `component-methods.md` with at least
   one method, and in `component-dependencies.md`.
4. Every service in `services.md` must reference at least one component from `components.md`.
5. Every story in `stories.md` must be addressable by at least one component, service, API,
   or event. Unmapped stories must be flagged with a reason.
6. Every entity in `data-models.md` must have exactly one owning component from `components.md`.
   No shared entity ownership.
7. Every API in `api-contracts.md` must use the error format defined in `cross-cutting.md`.
8. Every event in `event-catalog.md` must have at least one producer and at least one consumer
   mapped to components, services, or external systems.
9. Every external dependency in `external-dependencies.md` must have at least one consuming
   component or service.
10. All artifacts describe logical behaviour only — no language, framework, database, protocol,
    broker, or vendor specifics.
11. Circular component dependencies must be listed in `component-dependencies.md` with
    explicit justification.
