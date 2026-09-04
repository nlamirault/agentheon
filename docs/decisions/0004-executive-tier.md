---
adr: 0004
status: ✅ Accepted
deciders: Nicolas Lamirault
consulted:
informed:
date: 2026-09-04
spdx-license: Apache-2.0
---

# ADR-0004: Executive Tier (Two-Tier Pantheon)

## Context

Agentheon began as a flat set of single-domain specialists with one orchestrator
([ADR-0001](0001-zeus-as-sole-orchestrator.md)): Zeus routes, specialists
execute. As the pantheon grew to 22 deities, two gaps appeared:

- **No strategy layer.** Every deity owns a slice of *execution* (build, test,
  data, cost, …), but nobody owns a *domain's direction* — the C-level concerns a
  real software organization has: technology strategy, operations, finance,
  marketing, revenue, and company vision.
- **Zeus was doing two jobs at one level.** As the flat graph widened, Zeus had
  to route directly to any of 21 specialists, mixing "which executive owns this
  domain" with "which specialist does this task" in a single decision.

We want to add C-level roles (CEO, CTO, COO, CFO, CMO, CRO) without duplicating
specialist scope or turning Zeus into a strategist. The question: **how do the
C-level agents relate to the existing specialists?**

## Considered Options

1. **Two-tier hierarchy** — Zeus routes to an executive who owns a domain; the
   executive delegates *down* to its specialists. Executives decide direction;
   specialists execute.
2. **Flat peers** — the C-level agents are just more domain deities Zeus routes
   to directly, in the same tier as the 22 specialists.
3. **Fold into existing agents** — express C-level concerns as extra
   responsibilities on existing specialists (e.g. CTO duties on Athena), adding
   no new deities.

## Pros and Cons

### 1. Two-tier hierarchy

**Pros:**

- ✅ Mirrors a real org: a C-level owns the *why*/*what*, specialists the *how*.
- ✅ Zeus routes by domain to an executive; the executive owns the finer choice of
  specialist — one decision per tier, not 27 options at once.
- ✅ Executives carry the same least-privilege stance as Zeus (delegation +
  read-only inspection, no shell), so strategy stays structurally separate from
  execution.
- ✅ Expressed purely in the `handoffs` graph plus an optional `tier` field — no
  breaking schema change; the 22 specialists need no edits.

**Cons:**

- ❌ Adds a delegation hop for pure execution tasks (Zeus → executive → specialist).
- ❌ More agents to maintain and keep reachable in the routing matrix.

### 2. Flat peers

**Pros:**

- ✅ Simplest — matches the current flat model, no new concept.

**Cons:**

- ❌ Blurs strategy vs. execution: a CTO peer overlaps Athena/Hephaestus with no
  clear boundary.
- ❌ Widens Zeus's fan-out further and invites routing ambiguity.

### 3. Fold into existing agents

**Pros:**

- ✅ No new deities; smallest surface area.

**Cons:**

- ❌ Violates one-deity-one-domain: a specialist would own both execution and
  strategy for its area.
- ❌ No place for genuinely new domains (marketing, revenue, company vision).

## Decision

We will use **Option 1 — a two-tier hierarchy**. We add six executive deities —
**Gaia** (CEO, vision), **Hyperion** (CTO, technology strategy), **Hera** (COO,
operations & delivery), **Hades** (CFO, finance & capital), **Peitho** (CMO,
marketing & growth), and **Tyche** (CRO, revenue & sales) — bringing the pantheon
to 28.

- Zeus (`tier: orchestrator`) routes to the executive who owns a domain.
- Executives (`tier: executive`) set direction and delegate **down** to their
  specialists via `handoffs`. Cross-executive concerns return to Zeus;
  executives never route to each other, keeping delegation to two levels.
- Specialists (`tier: specialist`, the default when the field is absent) remain
  exactly as before and each stay reachable through their owning executive.

A new optional `tier` frontmatter field records the level; it drives grouping in
`team/routing.md` and the docs and is validated by `hack/validate-agents.sh`.
Overlapping C-level roles (CISO, CDO, CAIO, CPO, Chief Digital) are **folded**
into the specialist that already owns the domain (Argus, Demeter, Prometheus,
Kairos, Daedalus/Iris) rather than added as deities.

## Consequences

### Positive

- ✅ Clear three-way separation: routing (Zeus), strategy (executives), execution
  (specialists).
- ✅ New strategic domains (marketing, revenue, vision) have a home without
  stretching any specialist's scope.
- ✅ Executives inherit Zeus's least-privilege toolset override, so they cannot
  run code or do specialist work — enforced structurally, not by convention.

### Negative

- ❌ Pure execution requests take an extra hop through an executive.
- ❌ Six more profiles to maintain; the routing matrix must keep every specialist
  reachable through an executive.

### Neutral

- ↔️ The `tier` field is optional and defaults to `specialist`, so existing
  profiles are unchanged; only Zeus and the executives declare it explicitly.

## References

- [ADR-0001](0001-zeus-as-sole-orchestrator.md) — Zeus as the sole orchestrator
- [`docs/explanation/architecture.md`](../explanation/architecture.md) — orchestration, strategy, and gates
- [`docs/reference/agents.md`](../reference/agents.md) — agent catalog and profile schema
- [`team/workflow.md`](../../team/workflow.md) — two tiers and the delivery loop
- [`agents/zeus/README.md`](../../agents/zeus/README.md) — the orchestrator profile
