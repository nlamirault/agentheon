<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Run Your First Task Through the Pantheon

> **Tutorial** — learning-oriented. By the end you will have taken a single
> small task from request to review by following it through Agentheon's
> plan → build → test → review loop.

## What you'll learn

- Who the core agents are and what each one owns
- How Hermes routes a request to the right specialist
- How work advances through quality gates
- How a handoff carries context from one agent to the next

## Prerequisites

- The Agentheon repository cloned locally
- Read [`team/company.md`](../../team/company.md) — the shared team context
- Read [`team/workflow.md`](../../team/workflow.md) — the loop and gates

## Step 1 — Meet the entrypoint

Every request enters through **Hermes**, the orchestrator. Hermes never does
specialist work — it reads the request and routes it. Open
[`agents/hermes.md`](../../agents/hermes.md) and note its `domain` and `tools`.

*You should see:* a routing-only agent with `Task`, `Read`, and `Grep`.

## Step 2 — Follow the main loop

Open [`team/workflow.md`](../../team/workflow.md) and find the main loop. A
typical feature travels:

```text
Request → Hermes (route)
  → Kairos      prioritize
  → Athena      plan
  → Hephaestus  build
  → Artemis     test      GATE: PASS/FAIL
  → Argus       review    GATE: PASS/FAIL
  → Themis      comply    GATE: PASS/FAIL
```

*You should see:* each step names an agent, and gates decide whether work
advances.

## Step 3 — Read a handoff

Open [`team/handoff-template.md`](../../team/handoff-template.md). Every
transition between agents uses this format so context never gets lost.

*You should see:* From/To, phase, context, files, acceptance criteria, and
evidence fields.

## Step 4 — Trace one task end to end

Pick a tiny change (e.g. "fix a typo in the README"). Walk it through on paper:

1. Hermes routes it — is it worth a full plan, or a direct build?
2. Hephaestus makes the change.
3. Artemis checks it against acceptance criteria.
4. Argus reviews for correctness.

*You should see:* even a one-line change has an owner at each step and evidence
at each gate.

## What you learned

- Hermes is the only entrypoint and routes all work
- Specialists stay inside their domain and hand off along defined routes
- Nothing advances past a gate it hasn't passed
- Handoffs carry full context to prevent multi-agent failure

## Next steps

- [Install the pantheon into Hermes Agent](../how-to/install-the-pantheon.md)
- [Add a new agent to the pantheon](../how-to/add-a-new-agent.md)
- [Pantheon architecture](../explanation/architecture.md)
- [Agent catalog](../reference/agents.md)
