---
adr: 0001
status: ✅ Accepted
deciders: Nicolas Lamirault
consulted:
informed:
date: 2026-08-28
spdx-license: Apache-2.0
---

# ADR-0001: Zeus as the Sole Orchestrator

## Context

Agentheon is a pantheon of single-domain agents — each deity owns exactly one
domain (Athena plans, Hephaestus builds, Artemis tests, and so on). A system of
many narrow agents needs a way to decide *who* handles an incoming request and
*how* work flows between them.

Two concerns are in tension:

- **Routing** — deciding which agent should do a piece of work.
- **Execution** — actually doing the work inside a domain.

If routing knowledge is spread across every agent, the map of "who does what"
becomes implicit and tribal: each agent must know about every other agent's
domain to hand off correctly. That knowledge drifts, contradicts itself, and
cannot be tested. The project also names context loss between agents as the
number-one cause of multi-agent failure, which is worsened when there is no
single, authoritative model of how work moves through the system.

The decision: where does routing authority live?

## Considered Options

1. **Single orchestrator (Zeus)** — one entrypoint routes every request;
   specialists only execute within their domain.
2. **Peer-to-peer routing** — every agent knows the others and hands off
   directly, with no central router.
3. **Static rules file only** — a configuration file maps request types to
   agents, consulted by whichever agent receives the request first.

## Pros and Cons

### 1. Single orchestrator (Zeus)

**Pros:**

- ✅ Routing lives in exactly one model of the system (`team/routing.md`,
  compiled from the `handoffs` edges in agent frontmatter).
- ✅ The flow of work is legible and testable — one place to reason about.
- ✅ Specialists stay narrow: they execute and hand off, never route.
- ✅ Clean separation of concerns (routing vs. execution).

**Cons:**

- ❌ The orchestrator is a potential bottleneck.
- ❌ A single point of failure for request intake.

### 2. Peer-to-peer routing

**Pros:**

- ✅ No central bottleneck; agents hand off directly.
- ✅ Resilient to any single agent being unavailable.

**Cons:**

- ❌ Every agent must know every other agent's domain — routing knowledge is
  duplicated and drifts out of sync.
- ❌ The flow of work is implicit and hard to test or audit.
- ❌ Amplifies context loss, the project's stated #1 failure mode.

### 3. Static rules file only

**Pros:**

- ✅ Routing rules are explicit and version-controlled.
- ✅ No dedicated orchestrator agent to build.

**Cons:**

- ❌ Whichever agent reads the request still owns routing behavior, blurring the
  routing/execution split.
- ❌ No single actor to enforce handoff structure or carry context across hops.

## Decision

We will use **Option 1 — a single orchestrator (Zeus)**. Zeus is the only
entrypoint. It routes and never does specialist work; the specialists execute
and hand off along their declared routes. Zeus reads `team/routing.md`, which
is compiled from the machine-readable `handoffs` edges declared across the agent
profiles, so the "who does what" map has exactly one source of truth.

We accept the bottleneck and single-point-of-failure risks because a single
routing point makes the flow of work legible, testable, and free of the
tribal routing knowledge that peer-to-peer would require.

## Consequences

### Positive

- ✅ One authoritative, machine-readable routing model (`team/routing.md`).
- ✅ Specialists remain narrow and auditable, with explicit `does` / `does_not`
  boundaries.
- ✅ Context can be carried consistently across handoffs through a single
  coordinating actor.

### Negative

- ❌ Zeus is a bottleneck and a single point of failure for request intake.
- ❌ Every new agent must declare `handoffs` edges so the routing matrix stays
  complete.

### Neutral

- ↔️ Adding or changing routes means regenerating `team/routing.md` from
  frontmatter rather than editing agents ad hoc.

## References

- [`docs/explanation/architecture.md`](../explanation/architecture.md) — orchestration, handoffs, and gates
- [`team/company.md`](../../team/company.md) — shared team principles
- [`team/workflow.md`](../../team/workflow.md) — the plan → build → test → review → comply loop
- [`agents/zeus/README.md`](../../agents/zeus/README.md) — the orchestrator profile
