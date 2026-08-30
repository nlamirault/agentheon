# ADR Decision Capture — Reference

## When It Fires

Automatically after user approval of:

| Stage | Phase |
| ----- | ----- |
| Application Design | Inception |
| Functional Design | Construction (per unit) |
| NFR Design | Construction (per unit) |
| Infrastructure Design | Construction (per unit) |

No separate approval gate. Executes as part of completing the stage.

---

## Decision Taxonomy

A choice qualifies for an ADR when two or more alternatives were considered and one was selected.

| Category | Examples |
| -------- | -------- |
| Technology selection | Framework, database, messaging system, auth library, ORM |
| Architectural pattern | Microservices vs monolith, REST vs GraphQL, event-driven vs request-response |
| Cloud service selection | Lambda vs ECS/Fargate, RDS vs DynamoDB, S3 vs EFS, SQS vs SNS |
| Data model decision | Relational vs document, schema choices with explicit trade-offs |
| Cross-cutting concern | Logging strategy, error handling pattern, API versioning approach |
| Component pattern | Service mesh vs API gateway, sync vs async communication |

**Skip** when a stage documents an already-decided approach without evaluating alternatives.

---

## Execution Steps

1. Review the just-approved artifact
2. List every decision matching the taxonomy above
3. For each decision:
   a. Scan `docs/adr/*.md` for the highest existing number
   b. Increment and zero-pad to three digits
   c. Write `docs/adr/{NNN}-{kebab-case-decision}.md` from `assets/adr-template.md`
   d. Set `status: ✅ Accepted`
4. Append one audit entry per ADR to `<intent-dir>/audit/intent-audit.md` (use `assets/audit-entry-template.md`)
5. Update the ADR References section in `<intent-dir>/state/intent-state.md`
6. Rebuild `docs/adr/README.md` index table (number, title, status, date, AIDLC stage)

---

## ADR Index Format

`docs/adr/README.md` — rebuilt after every Decision Capture run:

```markdown
# Architecture Decision Records

| # | Title | Status | Date | AIDLC Stage |
|---|-------|--------|------|-------------|
| 001 | Choose REST over GraphQL | ✅ Accepted | 2026-05-19 | Application Design |
| 002 | Use Redis for caching | ✅ Accepted | 2026-05-19 | NFR Design / api-unit |
```

---

## Status Lifecycle

All AIDLC-generated ADRs start as `✅ Accepted`. To change a decision later:

1. Create a new ADR for the new choice
2. Update the old ADR: set status to `⌛️ Superseded`, add `Superseded by: {NNN}` under the Decision section

Valid transitions: `✅ Accepted` → `⌛️ Superseded` | `🪦 Deprecated`
