<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Pantheon Architecture: Orchestration, Handoffs, and Gates

> **Explanation** — understanding-oriented. This page discusses why Agentheon is
> shaped the way it is. For the how, see the
> [how-to guides](../how-to/); for the what, see the
> [reference](../reference/agents.md).

## The core idea

Agentheon is a **pantheon of single-domain agents**. Rather than one generalist
agent that tries to do everything, each deity owns exactly one domain and does
only that. Athena plans; she never writes implementation code. Hephaestus
builds; he never skips the design step. The narrowness is the point — a small,
sharp scope is easier to reason about, review, and trust.

## Why a single orchestrator

**Zeus is the only entrypoint.** Every request is routed through one place,
and Zeus itself does no specialist work. This keeps three concerns apart:

- **Routing** — deciding *who* should do the work (Zeus).
- **Strategy** — owning a domain's direction and delegating it (the executives).
- **Execution** — actually doing it (the specialists).

Centralizing routing means the map of "who does what" lives in exactly one
model of the system — the `handoffs` edges declared across the agent profiles,
compiled into `team/routing.md`. There is no implicit, tribal knowledge of how
work flows; it is machine-readable. The same frontmatter also compiles into
[`team/roster.md`](../../team/roster.md), the human-facing companion that groups
agents by tier with a "good fit" column for picking one by hand.

## Why a strategy tier

The pantheon is **two-tier**. Zeus routes to an **executive** (CEO, CTO, COO,
CFO, CMO, CRO) who owns a domain; the executive sets direction and delegates
**down** to the specialists who execute. This mirrors a real org: a C-level owns
the *why* and the *what*, specialists own the *how*. Executives carry the same
least-privilege stance as Zeus — delegation plus read-only inspection, no shell —
so strategy stays structurally separate from execution. Cross-executive concerns
return to Zeus; executives never route to each other, keeping delegation to two
levels. See [ADR 0004](../decisions/0004-executive-tier.md).

## Why gates instead of trust

Work moves through the loop **plan → build → test → review → comply**, and each
transition is a **gate** with a PASS/FAIL verdict:

```text
Kairos → Athena → Hephaestus → Artemis(GATE) → Argus(GATE) → Themis(GATE)
```

A gate is not a formality. Artemis returns PASS/FAIL against the acceptance
criteria; Argus returns PASS/FAIL on correctness and security; Themis on
licensing, DCO, and policy. Nothing advances past a gate it has not passed.
This is what lets a chain of autonomous agents stay honest: the guiding
principle is **evidence over claims** — "done" requires proof (test output, a
passing build, a diff), never an agent's say-so.

## Why handoffs carry full context

The project names context loss between agents as **the number-one cause of
multi-agent failure**. When Athena hands a plan to Hephaestus, the plan alone is
not enough — Hephaestus needs the goal, the constrained files, the acceptance
criteria, and the risks Athena already identified.

That is why every transition uses the [handoff template](../../team/handoff-template.md):
a structured From/To document carrying phase, context, files, acceptance
criteria, and evidence. Context travels *with* the work, so each agent starts
where the previous one left off instead of re-deriving it.

## Why persona and config are separate

Each agent is defined by exactly one file — `agents/<name>/README.md` and its
frontmatter — but the installer derives **three** artifacts from it, each with a
single concern:

- **`SOUL.md` — who the agent is.** Identity, voice, and behavioral stance. The
  persona traits (`archetype`, `big_five`, `comm_style`) are translated into
  prose, and from `big_five` the generator derives how the agent behaves at the
  moments that matter in a multi-agent team: **Under Pressure** (a failing gate,
  a short clock), **Disagreement** (how it disputes another agent's output), and
  **Blind Spots** (its own failure modes, each with a compensating correction).
  The point is *behavioral differentiation* — agents that reason and fail
  differently, not merely sound different.
- **`config.yaml` — how the agent runs.** Model, reasoning effort, toolsets,
  skills. Purely operational; carries no identity.
- **`AGENTS.md` — what the agent does.** Project mechanics: scope (`does` /
  `does_not`), handoff routes, shared-context pointers, and the finalization
  gate.

Keeping identity apart from runtime config is deliberate. A SOUL file that mixes
in file paths, tool lists, or workflow steps reads as weaker identity, and the
persona stays portable and model-agnostic — the same SOUL can run on a different
model by changing only `config.yaml`. For the same reason, credentials, memory,
cron schedules, and MCP servers are **never** part of the persona; they live in
runtime config and secret stores (see [ADR 0003](../decisions/0003-secret-management.md)).

Underneath every persona sits one shared floor. The
[baseline contract](../../team/baseline-contract.md) — authorization scope,
least privilege, destructive-action confirmation, bounded security work, and
evidence over claims — is injected verbatim into every `SOUL.md` as
**Non-Negotiable Boundaries**. It is written once and identical everywhere, and
it **outranks persona**: when a deity's character and the contract conflict, the
contract wins.

## How the pieces fit

```text
             ┌─────────┐
   Request ─▶│  Zeus   │  routes only
             └────┬────┘
                  │  (reads team/routing.md)
     ┌────────────┼────────────┬───────────┐
     ▼            ▼            ▼           ▼
  Kairos ─▶ Athena ─▶ Hephaestus ─▶ Artemis ─▶ Argus ─▶ Themis
 prioritize  plan       build      test⛩     review⛩  comply⛩
                                    (each ⛩ = PASS/FAIL gate)
```

Supporting specialists (Asclepius for debugging, Prometheus for AI/ML, Helios
for observability, and the rest) plug into the same loop along their own
declared handoff routes.

## Design trade-offs

- **Many narrow agents vs. one generalist.** More coordination overhead, but
  each agent is auditable and its boundaries are explicit (`does` / `does_not`).
- **Central orchestrator vs. peer-to-peer.** A single routing point is a
  potential bottleneck, but it makes the flow of work legible and testable.
- **Hard gates vs. speed.** Gates cost round-trips, but they prevent unverified
  or non-compliant work from shipping — the project treats them as
  non-negotiable.

## See also

- [`team/company.md`](../../team/company.md) — the working principles in full
- [`team/workflow.md`](../../team/workflow.md) — the loop and every gate
- [`team/baseline-contract.md`](../../team/baseline-contract.md) — the shared safety floor
- [`team/roster.md`](../../team/roster.md) — who's who, grouped by tier
- [Agent catalog](../reference/agents.md) — every agent and its domain
