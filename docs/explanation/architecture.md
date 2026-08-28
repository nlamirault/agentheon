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

**Hermes is the only entrypoint.** Every request is routed through one place,
and Hermes itself does no specialist work. This keeps two concerns apart:

- **Routing** — deciding *who* should do the work (Hermes).
- **Execution** — actually doing it (the specialists).

Centralizing routing means the map of "who does what" lives in exactly one
model of the system — the `handoffs` edges declared across the agent profiles,
compiled into `team/routing.md`. There is no implicit, tribal knowledge of how
work flows; it is machine-readable.

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

## How the pieces fit

```text
             ┌─────────┐
   Request ─▶│ Hermes  │  routes only
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
- [Agent catalog](../reference/agents.md) — every agent and its domain
